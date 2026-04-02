from fastapi import APIRouter, Depends

from ..auth import get_current_user
from ..models import User
from ..schemas import AuthMeResponse

router = APIRouter(prefix="/v1/auth", tags=["auth"])


@router.get("/me", response_model=AuthMeResponse)
def get_me(current_user: User = Depends(get_current_user)) -> AuthMeResponse:
    return AuthMeResponse(userId=current_user.id, email=current_user.email)
