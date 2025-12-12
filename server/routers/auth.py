"""
认证路由
处理用户注册、登录、登出等认证相关功能
"""

import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPAuthorizationCredentials

from server.database import get_pool
from server.middleware import (
    get_password_hash,
    verify_password,
    create_access_token,
    get_current_user,
    security
)
from server.models import (
    UserCreate,
    UserLogin,
    UserResponse,
    UserInfo,
    ChangePasswordRequest,
    BaseResponse,
    ErrorResponse
)

# 配置日志
logger = logging.getLogger(__name__)

# 创建路由
router = APIRouter(prefix="/api/auth", tags=["认证"])


@router.post("/register", response_model=BaseResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate):
    """
    用户注册
    
    Args:
        user_data: 用户注册数据（用户名和密码）
    
    Returns:
        注册成功响应，包含用户信息和 Token
    """
    pool = get_pool()
    
    try:
        with pool.get_connection() as conn:
            # 检查用户名是否已存在
            cursor = conn.execute(
                "SELECT id FROM users WHERE username = ?",
                (user_data.username,)
            )
            existing_user = cursor.fetchone()
            
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="用户名已存在，请选择其他用户名"
                )
            
            # 加密密码
            hashed_password = get_password_hash(user_data.password)
            
            # 创建用户
            cursor = conn.execute(
                """
                INSERT INTO users (username, password, created_at)
                VALUES (?, ?, datetime('now'))
                """,
                (user_data.username, hashed_password)
            )
            user_id = cursor.lastrowid
            
            # 创建用户设置记录
            conn.execute(
                """
                INSERT INTO user_settings (userId, created_at, updated_at)
                VALUES (?, datetime('now'), datetime('now'))
                """,
                (user_id,)
            )
            
            conn.commit()
            
            # 生成 Token
            token_data = {
                "user_id": user_id,
                "username": user_data.username
            }
            token = create_access_token(data=token_data)
            
            # 更新在线用户表
            conn.execute(
                """
                INSERT OR REPLACE INTO online_users (userId, username, last_heartbeat, current_action)
                VALUES (?, ?, datetime('now'), '注册')
                """,
                (user_id, user_data.username)
            )
            conn.commit()
            
            # 构建响应
            user_response = UserResponse(
                id=user_id,
                username=user_data.username,
                created_at=datetime.now().isoformat()
            )
            
            user_info = UserInfo(
                user=user_response,
                token=token,
                expires_in=60 * 24 * 60  # 24 小时（秒）
            )
            
            logger.info(f"用户注册成功: {user_data.username} (ID: {user_id})")
            
            return BaseResponse(
                success=True,
                message="注册成功",
                data=user_info.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"用户注册失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"注册失败: {str(e)}"
        )


@router.post("/login", response_model=BaseResponse)
async def login(login_data: UserLogin):
    """
    用户登录
    
    Args:
        login_data: 登录数据（用户名和密码）
    
    Returns:
        登录成功响应，包含用户信息和 Token
    """
    pool = get_pool()
    
    try:
        with pool.get_connection() as conn:
            # 查询用户
            cursor = conn.execute(
                "SELECT id, username, password FROM users WHERE username = ?",
                (login_data.username,)
            )
            user = cursor.fetchone()
            
            if user is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户名或密码错误"
                )
            
            user_id, username, hashed_password = user
            
            # 验证密码
            if not verify_password(login_data.password, hashed_password):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户名或密码错误"
                )
            
            # 更新最后登录时间
            conn.execute(
                "UPDATE users SET last_login_at = datetime('now') WHERE id = ?",
                (user_id,)
            )
            
            # 更新在线用户表
            conn.execute(
                """
                INSERT OR REPLACE INTO online_users (userId, username, last_heartbeat, current_action)
                VALUES (?, ?, datetime('now'), '登录')
                """,
                (user_id, username)
            )
            
            conn.commit()
            
            # 生成 Token
            token_data = {
                "user_id": user_id,
                "username": username
            }
            token = create_access_token(data=token_data)
            
            # 构建响应
            user_response = UserResponse(
                id=user_id,
                username=username,
                last_login_at=datetime.now().isoformat()
            )
            
            user_info = UserInfo(
                user=user_response,
                token=token,
                expires_in=60 * 24 * 60  # 24 小时（秒）
            )
            
            logger.info(f"用户登录成功: {username} (ID: {user_id})")
            
            return BaseResponse(
                success=True,
                message="登录成功",
                data=user_info.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"用户登录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"登录失败: {str(e)}"
        )


@router.post("/logout", response_model=BaseResponse)
async def logout(current_user: dict = Depends(get_current_user)):
    """
    用户登出
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        登出成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    username = current_user["username"]
    
    try:
        with pool.get_connection() as conn:
            # 从在线用户表中删除
            conn.execute(
                "DELETE FROM online_users WHERE userId = ?",
                (user_id,)
            )
            conn.commit()
            
            logger.info(f"用户登出: {username} (ID: {user_id})")
            
            return BaseResponse(
                success=True,
                message="登出成功"
            )
            
    except Exception as e:
        logger.error(f"用户登出失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"登出失败: {str(e)}"
        )


@router.get("/me", response_model=BaseResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """
    获取当前用户信息
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        当前用户信息
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            cursor = conn.execute(
                "SELECT id, username, created_at, last_login_at FROM users WHERE id = ?",
                (user_id,)
            )
            user = cursor.fetchone()
            
            if user is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="用户不存在"
                )
            
            user_response = UserResponse(
                id=user[0],
                username=user[1],
                created_at=user[2],
                last_login_at=user[3]
            )
            
            return BaseResponse(
                success=True,
                message="获取用户信息成功",
                data=user_response.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取用户信息失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取用户信息失败: {str(e)}"
        )


@router.post("/refresh", response_model=BaseResponse)
async def refresh_token(current_user: dict = Depends(get_current_user)):
    """
    刷新 Token（延长过期时间）
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        新的 Token
    """
    try:
        # 生成新 Token
        token_data = {
            "user_id": current_user["user_id"],
            "username": current_user["username"]
        }
        token = create_access_token(data=token_data)
        
        logger.info(f"Token 刷新成功: {current_user['username']} (ID: {current_user['user_id']})")
        
        return BaseResponse(
            success=True,
            message="Token 刷新成功",
            data={
                "token": token,
                "expires_in": 60 * 24 * 60  # 24 小时（秒）
            }
        )
        
    except Exception as e:
        logger.error(f"Token 刷新失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Token 刷新失败: {str(e)}"
        )


@router.post("/change-password", response_model=BaseResponse)
async def change_password(
    password_data: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    修改密码
    
    Args:
        password_data: 密码修改数据（旧密码和新密码）
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        修改密码成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 查询当前密码
            cursor = conn.execute(
                "SELECT password FROM users WHERE id = ?",
                (user_id,)
            )
            user = cursor.fetchone()
            
            if user is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="用户不存在"
                )
            
            hashed_password = user[0]
            
            # 验证旧密码
            if not verify_password(password_data.old_password, hashed_password):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="当前密码不正确"
                )
            
            # 更新密码
            new_hashed_password = get_password_hash(password_data.new_password)
            conn.execute(
                "UPDATE users SET password = ? WHERE id = ?",
                (new_hashed_password, user_id)
            )
            conn.commit()
            
            logger.info(f"用户修改密码成功: {current_user['username']} (ID: {user_id})")
            
            return BaseResponse(
                success=True,
                message="密码修改成功"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"修改密码失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"修改密码失败: {str(e)}"
        )

