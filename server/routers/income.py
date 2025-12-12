"""
进账管理路由
处理进账记录的增删改查功能
"""

import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Depends, Query

from server.database import get_pool
from server.middleware import get_current_user
from server.models import (
    IncomeCreate,
    IncomeUpdate,
    IncomeResponse,
    BaseResponse,
    PaginationParams,
    PaginatedResponse,
    DateRangeFilter
)

# 配置日志
logger = logging.getLogger(__name__)

# 创建路由
router = APIRouter(prefix="/api/income", tags=["进账管理"])


@router.get("", response_model=BaseResponse)
async def get_income_records(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=10000, description="每页数量（最大 10000）"),
    search: Optional[str] = Query(None, description="搜索关键词（备注）"),
    start_date: Optional[str] = Query(None, description="开始日期（ISO8601格式）"),
    end_date: Optional[str] = Query(None, description="结束日期（ISO8601格式）"),
    customer_id: Optional[int] = Query(None, description="客户ID筛选"),
    current_user: dict = Depends(get_current_user)
):
    """
    获取进账记录列表（支持分页、搜索、日期筛选）
    
    Args:
        page: 页码
        page_size: 每页数量
        search: 搜索关键词
        start_date: 开始日期
        end_date: 结束日期
        customer_id: 客户ID筛选
        current_user: 当前用户信息
    
    Returns:
        进账记录列表（分页）
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
                where_conditions.append("date(incomeDate) >= date(?)")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("date(incomeDate) <= date(?)")
                params.append(end_date)
            
            # 客户筛选
            if customer_id is not None:
                if customer_id == 0:
                    where_conditions.append("(customerId IS NULL OR customerId = 0)")
                else:
                    where_conditions.append("customerId = ?")
                    params.append(customer_id)
            
            where_clause = " AND ".join(where_conditions)
            
            # 获取总数
            count_cursor = conn.execute(
                f"SELECT COUNT(*) FROM income WHERE {where_clause}",
                tuple(params)
            )
            total = count_cursor.fetchone()[0]
            
            # 计算分页
            offset = (page - 1) * page_size
            total_pages = (total + page_size - 1) // page_size
            
            # 获取进账记录列表
            cursor = conn.execute(
                f"""
                SELECT id, userId, incomeDate, customerId, amount, discount, employeeId,
                       paymentMethod, note, created_at
                FROM income
                WHERE {where_clause}
                ORDER BY incomeDate DESC, id DESC
                LIMIT ? OFFSET ?
                """,
                tuple(params) + (page_size, offset)
            )
            rows = cursor.fetchall()
            
            # 转换为响应模型
            income_records = []
            for row in rows:
                income = IncomeResponse(
                    id=row[0],
                    userId=row[1],
                    incomeDate=row[2],
                    customerId=row[3],
                    amount=row[4],
                    discount=row[5] if row[5] else 0.0,
                    employeeId=row[6],
                    paymentMethod=row[7],
                    note=row[8],
                    created_at=row[9]
                )
                income_records.append(income.model_dump())
            
            paginated_data = PaginatedResponse(
                items=income_records,
                total=total,
                page=page,
                page_size=page_size,
                total_pages=total_pages
            )
            
            return BaseResponse(
                success=True,
                message="获取进账记录列表成功",
                data=paginated_data.model_dump()
            )
            
    except Exception as e:
        logger.error(f"获取进账记录列表失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取进账记录列表失败: {str(e)}"
        )


@router.get("/{income_id}", response_model=BaseResponse)
async def get_income_record(
    income_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    获取单个进账记录详情
    
    Args:
        income_id: 进账记录ID
        current_user: 当前用户信息
    
    Returns:
        进账记录详情
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, userId, incomeDate, customerId, amount, discount, employeeId,
                       paymentMethod, note, created_at
                FROM income
                WHERE id = ? AND userId = ?
                """,
                (income_id, user_id)
            )
            row = cursor.fetchone()
            
            if row is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="进账记录不存在或无权限访问"
                )
            
            income = IncomeResponse(
                id=row[0],
                userId=row[1],
                incomeDate=row[2],
                customerId=row[3],
                amount=row[4],
                discount=row[5] if row[5] else 0.0,
                employeeId=row[6],
                paymentMethod=row[7],
                note=row[8],
                created_at=row[9]
            )
            
            return BaseResponse(
                success=True,
                message="获取进账记录详情成功",
                data=income.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取进账记录详情失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取进账记录详情失败: {str(e)}"
        )


@router.post("", response_model=BaseResponse, status_code=status.HTTP_201_CREATED)
async def create_income_record(
    income_data: IncomeCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    创建进账记录
    
    Args:
        income_data: 进账数据
        current_user: 当前用户信息
    
    Returns:
        创建的进账记录
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 验证客户是否存在（如果提供了 customerId）
            if income_data.customerId is not None:
                customer_cursor = conn.execute(
                    "SELECT id FROM customers WHERE id = ? AND userId = ?",
                    (income_data.customerId, user_id)
                )
                if customer_cursor.fetchone() is None:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="客户不存在或无权限访问"
                    )
            
            # 验证员工是否存在（如果提供了 employeeId）
            if income_data.employeeId is not None:
                employee_cursor = conn.execute(
                    "SELECT id FROM employees WHERE id = ? AND userId = ?",
                    (income_data.employeeId, user_id)
                )
                if employee_cursor.fetchone() is None:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="员工不存在或无权限访问"
                    )
            
            # 插入进账记录
            cursor = conn.execute(
                """
                INSERT INTO income (userId, incomeDate, customerId, amount, discount, employeeId, paymentMethod, note, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                """,
                (
                    user_id,
                    income_data.incomeDate,
                    income_data.customerId,
                    income_data.amount,
                    income_data.discount,
                    income_data.employeeId,
                    income_data.paymentMethod.value,
                    income_data.note
                )
            )
            income_id = cursor.lastrowid
            conn.commit()
            
            # 获取创建的进账记录
            cursor = conn.execute(
                """
                SELECT id, userId, incomeDate, customerId, amount, discount, employeeId,
                       paymentMethod, note, created_at
                FROM income
                WHERE id = ?
                """,
                (income_id,)
            )
            row = cursor.fetchone()
            
            income = IncomeResponse(
                id=row[0],
                userId=row[1],
                incomeDate=row[2],
                customerId=row[3],
                amount=row[4],
                discount=row[5] if row[5] else 0.0,
                employeeId=row[6],
                paymentMethod=row[7],
                note=row[8],
                created_at=row[9]
            )
            
            logger.info(
                f"创建进账记录成功: 金额 {income_data.amount} (ID: {income_id}, 用户: {user_id})"
            )
            
            return BaseResponse(
                success=True,
                message="创建进账记录成功",
                data=income.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"创建进账记录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"创建进账记录失败: {str(e)}"
        )


@router.put("/{income_id}", response_model=BaseResponse)
async def update_income_record(
    income_id: int,
    income_data: IncomeUpdate,
    current_user: dict = Depends(get_current_user)
):
    """
    更新进账记录
    
    Args:
        income_id: 进账记录ID
        income_data: 进账更新数据
        current_user: 当前用户信息
    
    Returns:
        更新后的进账记录
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 检查进账记录是否存在
            cursor = conn.execute(
                "SELECT id FROM income WHERE id = ? AND userId = ?",
                (income_id, user_id)
            )
            existing_income = cursor.fetchone()
            
            if existing_income is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="进账记录不存在或无权限访问"
                )
            
            # 验证客户是否存在（如果修改了客户）
            if income_data.customerId is not None:
                if income_data.customerId != 0:
                    customer_cursor = conn.execute(
                        "SELECT id FROM customers WHERE id = ? AND userId = ?",
                        (income_data.customerId, user_id)
                    )
                    if customer_cursor.fetchone() is None:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="客户不存在或无权限访问"
                        )
            
            # 验证员工是否存在（如果修改了员工）
            if income_data.employeeId is not None:
                if income_data.employeeId != 0:
                    employee_cursor = conn.execute(
                        "SELECT id FROM employees WHERE id = ? AND userId = ?",
                        (income_data.employeeId, user_id)
                    )
                    if employee_cursor.fetchone() is None:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="员工不存在或无权限访问"
                        )
            
            # 构建更新字段
            update_fields = []
            update_values = []
            
            if income_data.incomeDate is not None:
                update_fields.append("incomeDate = ?")
                update_values.append(income_data.incomeDate)
            
            if income_data.customerId is not None:
                update_fields.append("customerId = ?")
                update_values.append(income_data.customerId if income_data.customerId != 0 else None)
            
            if income_data.amount is not None:
                update_fields.append("amount = ?")
                update_values.append(income_data.amount)
            
            if income_data.discount is not None:
                update_fields.append("discount = ?")
                update_values.append(income_data.discount)
            
            if income_data.employeeId is not None:
                update_fields.append("employeeId = ?")
                update_values.append(income_data.employeeId if income_data.employeeId != 0 else None)
            
            if income_data.paymentMethod is not None:
                update_fields.append("paymentMethod = ?")
                update_values.append(income_data.paymentMethod.value)
            
            if income_data.note is not None:
                update_fields.append("note = ?")
                update_values.append(income_data.note)
            
            if not update_fields:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="没有提供要更新的字段"
                )
            
            update_values.append(income_id)
            update_values.append(user_id)
            
            # 执行更新
            update_sql = f"""
                UPDATE income
                SET {', '.join(update_fields)}
                WHERE id = ? AND userId = ?
            """
            conn.execute(update_sql, tuple(update_values))
            conn.commit()
            
            # 获取更新后的进账记录
            cursor = conn.execute(
                """
                SELECT id, userId, incomeDate, customerId, amount, discount, employeeId,
                       paymentMethod, note, created_at
                FROM income
                WHERE id = ?
                """,
                (income_id,)
            )
            row = cursor.fetchone()
            
            income = IncomeResponse(
                id=row[0],
                userId=row[1],
                incomeDate=row[2],
                customerId=row[3],
                amount=row[4],
                discount=row[5] if row[5] else 0.0,
                employeeId=row[6],
                paymentMethod=row[7],
                note=row[8],
                created_at=row[9]
            )
            
            logger.info(f"更新进账记录成功: {income_id} (用户: {user_id})")
            
            return BaseResponse(
                success=True,
                message="更新进账记录成功",
                data=income.model_dump()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新进账记录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新进账记录失败: {str(e)}"
        )


@router.delete("/{income_id}", response_model=BaseResponse)
async def delete_income_record(
    income_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    删除进账记录
    
    Args:
        income_id: 进账记录ID
        current_user: 当前用户信息
    
    Returns:
        删除成功响应
    """
    pool = get_pool()
    user_id = current_user["user_id"]
    
    try:
        with pool.get_connection() as conn:
            # 检查进账记录是否存在
            cursor = conn.execute(
                "SELECT amount FROM income WHERE id = ? AND userId = ?",
                (income_id, user_id)
            )
            income = cursor.fetchone()
            
            if income is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="进账记录不存在或无权限访问"
                )
            
            # 删除进账记录
            conn.execute(
                "DELETE FROM income WHERE id = ? AND userId = ?",
                (income_id, user_id)
            )
            conn.commit()
            
            logger.info(f"删除进账记录成功: 金额 {income[0]} (ID: {income_id}, 用户: {user_id})")
            
            return BaseResponse(
                success=True,
                message="删除进账记录成功"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除进账记录失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除进账记录失败: {str(e)}"
        )

