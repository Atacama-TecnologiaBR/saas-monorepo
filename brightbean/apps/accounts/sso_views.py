"""
SSO endpoint: validates a LastSaaS JWT and creates a Django session.

Flow:
  1. User logs in on LastSaaS React frontend → receives JWT access token
  2. React redirects to  /social/sso/?token=<jwt>&next=<url>
  3. This view validates the JWT with the shared secret (LASTSAAS_JWT_SECRET)
  4. Creates or retrieves the matching Django User by email
  5. Logs the user in (creates Django session) and redirects to `next`
"""

import logging

import jwt
from django.conf import settings
from django.contrib.auth import get_user_model, login
from django.http import HttpResponseBadRequest
from django.shortcuts import redirect
from django.views.decorators.http import require_GET

logger = logging.getLogger(__name__)
User = get_user_model()

_SAFE_NEXT_PREFIXES = ("/", "")


def _is_safe_next(url: str) -> bool:
    return url.startswith("/") and not url.startswith("//")


@require_GET
def sso_login(request):
    token = request.GET.get("token", "").strip()
    next_url = request.GET.get("next", "/")

    if not _is_safe_next(next_url):
        next_url = "/"

    if not token:
        return HttpResponseBadRequest("Missing token")

    secret = getattr(settings, "LASTSAAS_JWT_SECRET", "")
    if not secret:
        logger.error("LASTSAAS_JWT_SECRET is not configured")
        return HttpResponseBadRequest("SSO not configured")

    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            options={"require": ["exp", "userId", "email"]},
        )
    except jwt.ExpiredSignatureError:
        return HttpResponseBadRequest("Token expired")
    except jwt.InvalidTokenError as exc:
        logger.warning("SSO token invalid: %s", exc)
        return HttpResponseBadRequest("Invalid token")

    if payload.get("tokenType") not in (None, "", "access"):
        return HttpResponseBadRequest("Wrong token type")

    email = payload["email"]
    display_name = payload.get("displayName", "")

    user, created = User.objects.get_or_create(
        email=email,
        defaults={"name": display_name, "is_active": True},
    )

    if not created and display_name and not user.name:
        user.name = display_name
        user.save(update_fields=["name"])

    login(request, user, backend="django.contrib.auth.backends.ModelBackend")
    logger.info("SSO login: %s (created=%s)", email, created)

    return redirect(next_url)
