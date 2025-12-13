"""
汇款管理路由
处理汇款记录的增删改查功能
"""

import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Depends, Query

from server.database import get_pool
from server.middleware import get_current_user
from server.models import (
    RemittanceCreate,
    RemittanceUpdate,
    RemittanceResponse,
    BaseResponse,
    PaginationParams,
    PaginatedResponse,
    DateRangeFilter
)

# 配置日志
logger = logging.getLogger(__name__)

# 创建路由
router = APIRouter(prefix="/api/remittance", tags=["汇款管理"])


@router.get("", response_model=BaseResponse)
async def get_remittance_records(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=10000, description="每页数量（最大 10000）"),
    search: Optional[str] = Query(None, description="搜索关键词（备注）"),
    start_date: Optional[str] = Query(None, description="开始日期（ISO8601格式）"),
    end_date: Optional[str] = Query(None, description="结束日期（ISO8601格式）"),
    supplier_id: Optional[int] = Query(None, description="供应商ID筛选"),
    current_user: dict = Depends(get_current_user)
):
    """
    获取汇款记录列表（支持分页、搜索、日期筛选）
    
    Args:
        page: 页码
        page_size: 每页数量
        search: 搜索关键词
        start_date: 开始日期
        end_date: 结束日期
        supplier_id: 供应商ID筛选
        current_user: 当前用户信息
    
    Returns:
        汇款记录列表（分页）
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 构建查询条件
            where_conditions = ["userId = ?"]
            params = [user_id]
            
            # 搜索条件
            if search:
                where_conditions.append("note LIKE ?")
                params.append(f"%{search}%")
            
            # 日期范围筛选
            if start_date:
                where_conditions.append("date(remittanceDate) >= date(?)")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("date(remittanceDate) <= date(?)")
                params.append(end_date)
            
            # 供应商筛选
            if supplier_id is not None:
                if supplier_id == 0:
                    where_conditions.append("(supplierId IS NULL OR supplierId = 0)")
                else:
                    where_conditions.append("supplierId = ?")
                    params.append(supplier_id)
            
            where_clause = " AND ".join(where_conditions)
            
            # 获取总数
            count_cursor = conn.execute(
                f"SELECT COUNT(*) FROM remittance WHERE {where_clause}",
                tuple(params)
            )
            total = count_cursor.fetchone()[0]
            
            # 计算分页
            offset = (page - 1) * page_size
            total_pages = (total + page_size - 1) // page_size
            
            # 获取汇款记录列表
            cursor = conn.execute(
                f"""
                SELECT id, userId, remittanceDate, supplierId, amount, employeeId,
                       paymentMethod, note, created_at
                FROM remittance
                WHERE {where_clause}
                ORDER BY remittanceDate DESC, id DESC
                LIMIT ? OFFSET ?
                """,
                tuple(params) + (page_size, offset)
            )
            rows = cursor.fetchall()
            
            # 转换为响应模型
            remittance_records = []
            for row in rows:
                remittance = RemittanceResponse(
                    id=row[0],
                    userId=row[1],
                    remittanceDate=row[2],
                    supplierId=row[3],
                    amount=row[4],
                    employeeId=row[5],
                    paymentMethod=row[6],
                    note=row[7],
                    created_at=row[8]
                )
                remittance_records.append(remittance.model_dump())
            
            paginated_data = PaginatedResponse(
                items=remittance_records,
                total=total,
                page=page,
                page_size=page_size,
                total_pages=total_pages
            )
            
            return BaseResponse(
                success=True,
                message="获取汇款记录列表成功",
                data=paginated_data.model_dump()
            )
            
    except Exception as e:
        logger.error(f"获取汇款记录列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取汇款记录列表失败: {str(e)}"
        )


@router.get("/{remittance_id}", response_model=BaseResponse)
async def get_remittance_record(
    remittance_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    获取单个汇款记录详情
    
    Args:
        remittance_id: 汇款记录ID
        current_user: 当前用户信息
    
    Returns:
        汇款记录详情
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, userId, remittanceDate, supplierId, amount, employeeId,
                       paymentMethod, note, created_at
                FROM remittance
                WHERE id = ? AND userId = ?
                """,
                (remittance_id, user_id)
            )
            row = cursor.fetchone()
            
            if row is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="汇款记录不存在或无权限访问"
                )
            
            remittance = RemittanceResponse(
                id=row[0],
                userId=row[1],
                remittanceDate=row[2],
                supplierId=row[3],
                amount=row[4],
                employeeId=row[5],
                paymentMethod=row[6],
                note=row[7],
                created_at=row[8]
            )
            
            return BaseResponse(
                success=True,
                message="获取汇款记录详情成功",
                data=remittance.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取汇款记录详情失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取汇款记录详情失败: {str(e)}"
        )


@router.post("", response_model=BaseResponse, status_code=status.HTTP_201_CREATED)
async def create_remittance_record(
    remittance_data: RemittanceCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    创建汇款记录
    
    Args:
        remittance_data: 汇款数据
        current_user: 当前用户信息
    
    Returns:
        创建的汇款记录
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 验证供应商是否存在（如果提供了 supplierId）
            if remittance_data.supplierId is not None:
                supplier_cursor = conn.execute(
                    "SELECT id FROM suppliers WHERE id = ? AND userId = ?",
                    (remittance_data.supplierId, user_id)
                )
                if supplier_cursor.fetchone() is None:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="供应商不存在或无权限访问"
                    )
            
            # 验证员工是否存在（如果提供了 employeeId）
            if remittance_data.employeeId is not None:
                employee_cursor = conn.execute(
                    "SELECT id FROM employees WHERE id = ? AND userId = ?",
                    (remittance_data.employeeId, user_id)
                )
                if employee_cursor.fetchone() is None:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="员工不存在或无权限访问"
                    )
            
            # 插入汇款记录
            cursor = conn.execute(
                """
                INSERT INTO remittance (userId, remittanceDate, supplierId, amount, employeeId, paymentMethod, note, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
                """,
                (
                    user_id,
                    remittance_data.remittanceDate,
                    remittance_data.supplierId,
                    remittance_data.amount,
                    remittance_data.employeeId,
                    remittance_data.paymentMethod.value,
                    remittance_data.note
                )
            )
            remittance_id = cursor.lastrowid
            conn.commit()
            
            # 获取创建的汇款记录
            cursor = conn.execute(
                """
                SELECT id, userId, remittanceDate, supplierId, amount, employeeId,
                       paymentMethod, note, created_at
                FROM remittance
                WHERE id = ?
                """,
                (remittance_id,)
            )
            row = cursor.fetchone()
            
            remittance = RemittanceResponse(
                id=row[0],
                userId=row[1],
                remittanceDate=row[2],
                supplierId=row[3],
                amount=row[4],
                employeeId=row[5],
                paymentMethod=row[6],
                note=row[7],
                created_at=row[8]
            )
            
            logger.info(
                f"创建汇款记录成功: 金额 {remittance_data.amount} (ID: {remittance_id}, 用户: {user_id})"
            )
            
            return BaseResponse(
                success=True,
                message="创建汇款记录成功",
                data=remittance.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"创建汇款记录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"创建汇款记录失败: {str(e)}"
        )


@router.put("/{remittance_id}", response_model=BaseResponse)
async def update_remittance_record(
    remittance_id: int,
    remittance_data: RemittanceUpdate,
    current_user: dict = Depends(get_current_user)
):
    """
    更新汇款记录
    
    Args:
        remittance_id: 汇款记录ID
        remittance_data: 汇款更新数据
        current_user: 当前用户信息
    
    Returns:
        更新后的汇款记录
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 检查汇款记录是否存在
            cursor = conn.execute(
                "SELECT id FROM remittance WHERE id = ? AND userId = ?",
                (remittance_id, user_id)
            )
            existing_remittance = cursor.fetchone()
            
            if existing_remittance is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="汇款记录不存在或无权限访问"
                )
            
            # 验证供应商是否存在（如果修改了供应商）
            if remittance_data.supplierId is not None:
                if remittance_data.supplierId != 0:
                    supplier_cursor = conn.execute(
                        "SELECT id FROM suppliers WHERE id = ? AND userId = ?",
                        (remittance_data.supplierId, user_id)
                    )
                    if supplier_cursor.fetchone() is None:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="供应商不存在或无权限访问"
                        )
            
            # 验证员工是否存在（如果修改了员工）
            if remittance_data.employeeId is not None:
                if remittance_data.employeeId != 0:
                    employee_cursor = conn.execute(
                        "SELECT id FROM employees WHERE id = ? AND userId = ?",
                        (remittance_data.employeeId, user_id)
                    )
                    if employee_cursor.fetchone() is None:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="员工不存在或无权限访问"
                        )
            
            # 构建更新字段
            update_fields = []
            update_values = []
            
            if remittance_data.remittanceDate is not None:
                update_fields.append("remittanceDate = ?")
                update_values.append(remittance_data.remittanceDate)
            
            if remittance_data.supplierId is not None:
                update_fields.append("supplierId = ?")
                update_values.append(remittance_data.supplierId if remittance_data.supplierId != 0 else None)
            
            if remittance_data.amount is not None:
                update_fields.append("amount = ?")
                update_values.append(remittance_data.amount)
            
            if remittance_data.employeeId is not None:
                update_fields.append("employeeId = ?")
                update_values.append(remittance_data.employeeId if remittance_data.employeeId != 0 else None)
            
            if remittance_data.paymentMethod is not None:
                update_fields.append("paymentMethod = ?")
                update_values.append(remittance_data.paymentMethod.value)
            
            if remittance_data.note is not None:
                update_fields.append("note = ?")
                update_values.append(remittance_data.note)
            
            if not update_fields:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="没有提供要更新的字段"
                )
            
            update_values.append(remittance_id)
            update_values.append(user_id)
            
            # 执行更新
            update_sql = f"""
                UPDATE remittance
                SET {', '.join(update_fields)}
                WHERE id = ? AND userId = ?
            """
            conn.execute(update_sql, tuple(update_values))
            conn.commit()
            
            # 获取更新后的汇款记录
            cursor = conn.execute(
                """
                SELECT id, userId, remittanceDate, supplierId, amount, employeeId,
                       paymentMethod, note, created_at
                FROM remittance
                WHERE id = ?
                """,
                (remittance_id,)
            )
            row = cursor.fetchone()
            
            remittance = RemittanceResponse(
                id=row[0],
                userId=row[1],
                remittanceDate=row[2],
                supplierId=row[3],
                amount=row[4],
                employeeId=row[5],
                paymentMethod=row[6],
                note=row[7],
                created_at=row[8]
            )
            
            logger.info(f"更新汇款记录成功: {remittance_id} (用户: {user_id})")
            
            return BaseResponse(
                success=True,
                message="更新汇款记录成功",
                data=remittance.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新汇款记录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新汇款记录失败: {str(e)}"
        )


@router.delete("/{remittance_id}", response_model=BaseResponse)
async def delete_remittance_record(
    remittance_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    删除汇款记录
    
    Args:
        remittance_id: 汇款记录ID
        current_user: 当前用户信息
    
    Returns:
        删除成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 检查汇款记录是否存在
            cursor = conn.execute(
                "SELECT amount FROM remittance WHERE id = ? AND userId = ?",
                (remittance_id, user_id)
            )
            remittance = cursor.fetchone()
            
            if remittance is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="汇款记录不存在或无权限访问"
                )
            
            # 删除汇款记录
            conn.execute(
                "DELETE FROM remittance WHERE id = ? AND userId = ?",
                (remittance_id, user_id)
            )
            conn.commit()
            
            logger.info(f"删除汇款记录成功: 金额 {remittance[0]} (ID: {remittance_id}, 用户: {user_id})")
            
            return BaseResponse(
                success=True,
                message="删除汇款记录成功"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除汇款记录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除汇款记录失败: {str(e)}"
        )


