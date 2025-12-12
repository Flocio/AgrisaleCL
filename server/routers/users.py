"""
用户在线状态管理路由
处理用户心跳、在线用户列表、操作状态更新等功能
"""

import logging
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, HTTPException, status, Depends

from server.database import get_pool
from server.middleware import get_current_user
from server.models import (
    OnlineUserUpdate,
    OnlineUserResponse,
    BaseResponse,
    ErrorResponse
)

# 配置日志
logger = logging.getLogger(__name__)

# 创建路由
router = APIRouter(prefix="/api/users", tags=["用户状态"])

# 在线用户超时时间（秒），超过此时间未心跳视为离线
ONLINE_TIMEOUT_SECONDS = 60  # 1 分钟


@router.post("/heartbeat", response_model=BaseResponse)
async def update_heartbeat(
    action_data: Optional[OnlineUserUpdate] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    更新用户心跳和当前操作
    
    客户端应该定期调用此接口（建议每 5-10 秒）来保持在线状态
    
    Args:
        action_data: 可选的当前操作描述（如"正在查看产品列表"）
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        心跳更新成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    username = current_user["username"]
    current_action = action_data.current_action if action_data else None
    
    try:
        with pool.get_connection() as conn:
            # 更新或插入在线用户记录
            conn.execute(
                """
                INSERT OR REPLACE INTO online_users (userId, username, last_heartbeat, current_action)
                VALUES (?, ?, datetime('now'), ?)
                """,
                (user_id, username, current_action)
            )
            conn.commit()
            
            logger.debug(f"用户心跳更新: {username} (ID: {user_id}), 操作: {current_action}")
            
            return BaseResponse(
                success=True,
                message="心跳更新成功"
            )
            
    except Exception as e:
        logger.error(f"更新心跳失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新心跳失败: {str(e)}"
        )


@router.get("/online", response_model=BaseResponse)
async def get_online_users(
    current_user: dict = Depends(get_current_user)
):
    """
    获取当前在线用户列表
    
    只返回在超时时间内的活跃用户
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        在线用户列表
    """
    pool = get_pool()
    current_user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 先清理过期的在线用户
            _cleanup_expired_users(conn)
            
            # 查询所有在线用户（在超时时间内的）
            # 使用 SQLite 的 datetime 函数计算超时阈值
            cursor = conn.execute(
                """
                SELECT userId, username, last_heartbeat, current_action
                FROM online_users
                WHERE datetime(last_heartbeat) > datetime('now', '-' || ? || ' seconds')
                ORDER BY last_heartbeat DESC
                """,
                (ONLINE_TIMEOUT_SECONDS,)
            )
            rows = cursor.fetchall()
            
            # 转换为响应模型
            online_users = []
            for row in rows:
                # 排除当前用户自己（可选，根据需要决定是否显示自己）
                # if row[0] == current_user_id:
                #     continue
                
                online_user = OnlineUserResponse(
                    userId=row[0],
                    username=row[1],
                    last_heartbeat=row[2],
                    current_action=row[3]
                )
                online_users.append(online_user.model_dump())
            
            logger.info(f"获取在线用户列表: {len(online_users)} 个用户在线")
            
            return BaseResponse(
                success=True,
                message="获取在线用户列表成功",
                data={
                    "online_users": online_users,
                    "count": len(online_users)
                }
            )
            
    except Exception as e:
        logger.error(f"获取在线用户列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取在线用户列表失败: {str(e)}"
        )


@router.get("/online/count", response_model=BaseResponse)
async def get_online_users_count(
    current_user: dict = Depends(get_current_user)
):
    """
    获取当前在线用户数量（轻量级接口）
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        在线用户数量
    """
    pool = get_pool()
    
    try:
        with pool.get_connection() as conn:
            # 先清理过期的在线用户
            _cleanup_expired_users(conn)
            
            # 统计在线用户数量
            cursor = conn.execute(
                """
                SELECT COUNT(*) FROM online_users
                WHERE datetime(last_heartbeat) > datetime('now', '-' || ? || ' seconds')
                """,
                (ONLINE_TIMEOUT_SECONDS,)
            )
            count = cursor.fetchone()[0]
            
            return BaseResponse(
                success=True,
                message="获取在线用户数量成功",
                data={"count": count}
            )
            
    except Exception as e:
        logger.error(f"获取在线用户数量失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取在线用户数量失败: {str(e)}"
        )


@router.post("/online/update-action", response_model=BaseResponse)
async def update_current_action(
    action_data: OnlineUserUpdate,
    current_user: dict = Depends(get_current_user)
):
    """
    更新当前操作描述
    
    当用户执行特定操作时调用此接口，用于显示"XXX 正在查看/编辑..."
    
    Args:
        action_data: 当前操作描述
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        更新成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    username = current_user["username"]
    
    try:
        with pool.get_connection() as conn:
            # 更新当前操作，同时更新心跳时间
            conn.execute(
                """
                UPDATE online_users
                SET current_action = ?, last_heartbeat = datetime('now')
                WHERE userId = ?
                """,
                (action_data.current_action, user_id)
            )
            
            # 如果用户不在在线列表中，添加进去
            if conn.total_changes == 0:
                conn.execute(
                    """
                    INSERT OR REPLACE INTO online_users (userId, username, last_heartbeat, current_action)
                    VALUES (?, ?, datetime('now'), ?)
                    """,
                    (user_id, username, action_data.current_action)
                )
            
            conn.commit()
            
            logger.debug(f"更新用户操作: {username} (ID: {user_id}) - {action_data.current_action}")
            
            return BaseResponse(
                success=True,
                message="操作状态更新成功"
            )
            
    except Exception as e:
        logger.error(f"更新操作状态失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新操作状态失败: {str(e)}"
        )


@router.post("/online/clear-action", response_model=BaseResponse)
async def clear_current_action(
    current_user: dict = Depends(get_current_user)
):
    """
    清除当前操作描述
    
    当用户离开某个操作页面时调用，清除操作状态
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        清除成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 清除操作描述，但保持在线状态
            conn.execute(
                """
                UPDATE online_users
                SET current_action = NULL, last_heartbeat = datetime('now')
                WHERE userId = ?
                """,
                (user_id,)
            )
            conn.commit()
            
            logger.debug(f"清除用户操作: {user_id}")
            
            return BaseResponse(
                success=True,
                message="操作状态清除成功"
            )
            
    except Exception as e:
        logger.error(f"清除操作状态失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"清除操作状态失败: {str(e)}"
        )


@router.post("/online/cleanup", response_model=BaseResponse)
async def cleanup_expired_users(
    current_user: dict = Depends(get_current_user)
):
    """
    手动清理过期的在线用户记录（管理员功能）
    
    通常系统会自动清理，此接口用于手动触发
    
    Args:
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        清理结果
    """
    pool = get_pool()
    
    try:
        with pool.get_connection() as conn:
            deleted_count = _cleanup_expired_users(conn)
            
            logger.info(f"清理过期在线用户: 删除了 {deleted_count} 条记录")
            
            return BaseResponse(
                success=True,
                message=f"清理完成，删除了 {deleted_count} 条过期记录",
                data={"deleted_count": deleted_count}
            )
            
    except Exception as e:
        logger.error(f"清理过期用户失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"清理过期用户失败: {str(e)}"
        )


def _cleanup_expired_users(conn) -> int:
    """
    清理过期的在线用户记录（内部函数）
    
    Args:
        conn: 数据库连接
    
    Returns:
        删除的记录数
    """
    try:
        # 使用 SQLite 的 datetime 函数计算超时阈值
        cursor = conn.execute(
            """
            DELETE FROM online_users
            WHERE datetime(last_heartbeat) <= datetime('now', '-' || ? || ' seconds')
            """,
            (ONLINE_TIMEOUT_SECONDS,)
        )
        deleted_count = cursor.rowcount
        conn.commit()
        return deleted_count
    except Exception as e:
        logger.error(f"清理过期用户时出错: {e}")
        return 0


@router.get("/online/{user_id}/status", response_model=BaseResponse)
async def get_user_online_status(
    user_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    获取指定用户的在线状态
    
    Args:
        user_id: 要查询的用户ID
        current_user: 当前用户信息（从 Token 获取）
    
    Returns:
        用户在线状态
    """
    pool = get_pool()
    
    try:
        with pool.get_connection() as conn:
            # 先清理过期的在线用户
            _cleanup_expired_users(conn)
            
            # 查询指定用户的在线状态
            cursor = conn.execute(
                """
                SELECT userId, username, last_heartbeat, current_action
                FROM online_users
                WHERE userId = ?
                """,
                (user_id,)
            )
            row = cursor.fetchone()
            
            if row is None:
                return BaseResponse(
                    success=True,
                    message="用户不在线",
                    data={
                        "is_online": False,
                        "user_id": user_id
                    }
                )
            
            # 检查是否在超时时间内（使用 SQLite 函数）
            cursor_check = conn.execute(
                """
                SELECT CASE 
                    WHEN datetime(last_heartbeat) > datetime('now', '-' || ? || ' seconds')
                    THEN 1 ELSE 0 END as is_online
                FROM online_users
                WHERE userId = ?
                """,
                (ONLINE_TIMEOUT_SECONDS, user_id)
            )
            check_result = cursor_check.fetchone()
            is_online = check_result[0] == 1 if check_result else False
            
            if is_online:
                online_user = OnlineUserResponse(
                    userId=row[0],
                    username=row[1],
                    last_heartbeat=row[2],
                    current_action=row[3]
                )
                return BaseResponse(
                    success=True,
                    message="用户在线",
                    data={
                        "is_online": True,
                        "user": online_user.model_dump()
                    }
                )
            else:
                # 用户已超时，删除记录
                conn.execute("DELETE FROM online_users WHERE userId = ?", (user_id,))
                conn.commit()
                
                return BaseResponse(
                    success=True,
                    message="用户不在线",
                    data={
                        "is_online": False,
                        "user_id": user_id
                    }
                )
            
    except Exception as e:
        logger.error(f"获取用户在线状态失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取用户在线状态失败: {str(e)}"
        )

