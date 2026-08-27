from app.schemas.post import CommentCreate, CommentResponse

CommentCreateSchema = CommentCreate
CommentOutSchema = CommentResponse

__all__ = ["CommentCreate", "CommentResponse", "CommentCreateSchema", "CommentOutSchema"]
