"""
用户设置管理路由
处理用户设置的获取和更新
"""

import logging
from fastapi import APIRouter, HTTPException, status, Depends

from server.database import get_pool
from server.middleware import get_current_user
from server.models import (
    UserSettingsUpdate,
    UserSettingsResponse,
    BaseResponse
)

# 配置日志
logger = logging.getLogger(__name__)

# 创建路由
router = APIRouter(prefix="/api/settings", tags=["用户设置"])


@router.get("", response_model=BaseResponse)
async def get_user_settings(
    current_user: dict = Depends(get_current_user)
):
    """
    获取当前用户设置
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        用户设置信息
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, userId, deepseek_api_key, deepseek_model, deepseek_temperature,
                       deepseek_max_tokens, dark_mode, auto_backup_enabled, auto_backup_interval,
                       auto_backup_max_count, last_backup_time, show_online_users,
                       created_at, updated_at
                FROM user_settings
                WHERE userId = ?
                """,
                (user_id,)
            )
            row = cursor.fetchone()
            
            if row is None:
                # 如果用户设置不存在，创建默认设置
                cursor = conn.execute(
                    """
                    INSERT INTO user_settings (userId, created_at, updated_at)
                    VALUES (?, datetime('now'), datetime('now'))
                    """,
                    (user_id,)
                )
                conn.commit()
                
                # 再次查询
                cursor = conn.execute(
                    """
                    SELECT id, userId, deepseek_api_key, deepseek_model, deepseek_temperature,
                           deepseek_max_tokens, dark_mode, auto_backup_enabled, auto_backup_interval,
                           auto_backup_max_count, last_backup_time, show_online_users,
                           created_at, updated_at
                    FROM user_settings
                    WHERE userId = ?
                    """,
                    (user_id,)
                )
                row = cursor.fetchone()
            
            settings = UserSettingsResponse(
                id=row[0],
                userId=row[1],
                deepseek_api_key=row[2],
                deepseek_model=row[3] if row[3] else "deepseek-chat",
                deepseek_temperature=row[4] if row[4] is not None else 0.7,
                deepseek_max_tokens=row[5] if row[5] is not None else 2000,
                dark_mode=row[6] if row[6] is not None else 0,
                auto_backup_enabled=row[7] if row[7] is not None else 0,
                auto_backup_interval=row[8] if row[8] is not None else 15,
                auto_backup_max_count=row[9] if row[9] is not None else 20,
                last_backup_time=row[10],
                show_online_users=row[11] if row[11] is not None else 1,
                created_at=row[12],
                updated_at=row[13]
            )
            
            return BaseResponse(
                success=True,
                message="获取用户设置成功",
                data=settings.model_dump()
            )
            
    except Exception as e:
        logger.error(f"获取用户设置失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取用户设置失败: {str(e)}"
        )


@router.put("", response_model=BaseResponse)
async def update_user_settings(
    settings_data: UserSettingsUpdate,
    current_user: dict = Depends(get_current_user)
):
    """
    更新用户设置
    
    Args:
        settings_data: 设置更新数据
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        更新后的用户设置
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 检查用户设置是否存在
            cursor = conn.execute(
                "SELECT id FROM user_settings WHERE userId = ?",
                (user_id,)
            )
            existing = cursor.fetchone()
            
            if existing is None:
                # 如果不存在，先创建
                cursor = conn.execute(
                    """
                    INSERT INTO user_settings (userId, created_at, updated_at)
                    VALUES (?, datetime('now'), datetime('now'))
                    """,
                    (user_id,)
                )
                conn.commit()
            
            # 构建更新字段
            update_fields = []
            update_values = []
            
            if settings_data.deepseek_api_key is not None:
                update_fields.append("deepseek_api_key = ?")
                update_values.append(settings_data.deepseek_api_key)
            
            if settings_data.deepseek_model is not None:
                update_fields.append("deepseek_model = ?")
                update_values.append(settings_data.deepseek_model)
            
            if settings_data.deepseek_temperature is not None:
                update_fields.append("deepseek_temperature = ?")
                update_values.append(settings_data.deepseek_temperature)
            
            if settings_data.deepseek_max_tokens is not None:
                update_fields.append("deepseek_max_tokens = ?")
                update_values.append(settings_data.deepseek_max_tokens)
            
            if settings_data.dark_mode is not None:
                update_fields.append("dark_mode = ?")
                update_values.append(settings_data.dark_mode)
            
            if settings_data.auto_backup_enabled is not None:
                update_fields.append("auto_backup_enabled = ?")
                update_values.append(settings_data.auto_backup_enabled)
            
            if settings_data.auto_backup_interval is not None:
                update_fields.append("auto_backup_interval = ?")
                update_values.append(settings_data.auto_backup_interval)
            
            if settings_data.auto_backup_max_count is not None:
                update_fields.append("auto_backup_max_count = ?")
                update_values.append(settings_data.auto_backup_max_count)
            
            if settings_data.show_online_users is not None:
                update_fields.append("show_online_users = ?")
                update_values.append(settings_data.show_online_users)
            
            if settings_data.last_backup_time is not None:
                update_fields.append("last_backup_time = ?")
                update_values.append(settings_data.last_backup_time)
            
            if not update_fields:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="没有提供要更新的字段"
                )
            
            # 更新更新时间
            update_fields.append("updated_at = datetime('now')")
            update_values.append(user_id)
            
            # 执行更新
            update_sql = f"""
                UPDATE user_settings
                SET {', '.join(update_fields)}
                WHERE userId = ?
            """
            conn.execute(update_sql, tuple(update_values))
            conn.commit()
            
            # 获取更新后的设置
            cursor = conn.execute(
                """
                SELECT id, userId, deepseek_api_key, deepseek_model, deepseek_temperature,
                       deepseek_max_tokens, dark_mode, auto_backup_enabled, auto_backup_interval,
                       auto_backup_max_count, last_backup_time, show_online_users,
                       created_at, updated_at
                FROM user_settings
                WHERE userId = ?
                """,
                (user_id,)
            )
            row = cursor.fetchone()
            
            settings = UserSettingsResponse(
                id=row[0],
                userId=row[1],
                deepseek_api_key=row[2],
                deepseek_model=row[3] if row[3] else "deepseek-chat",
                deepseek_temperature=row[4] if row[4] is not None else 0.7,
                deepseek_max_tokens=row[5] if row[5] is not None else 2000,
                dark_mode=row[6] if row[6] is not None else 0,
                auto_backup_enabled=row[7] if row[7] is not None else 0,
                auto_backup_interval=row[8] if row[8] is not None else 15,
                auto_backup_max_count=row[9] if row[9] is not None else 20,
                last_backup_time=row[10],
                show_online_users=row[11] if row[11] is not None else 1,
                created_at=row[12],
                updated_at=row[13]
            )
            
            logger.info(f"更新用户设置成功: {user_id}")
            
            return BaseResponse(
                success=True,
                message="更新用户设置成功",
                data=settings.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新用户设置失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新用户设置失败: {str(e)}"
        )

