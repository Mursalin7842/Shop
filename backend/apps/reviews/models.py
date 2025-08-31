from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from apps.products.models import Product
from apps.orders.models import Order, OrderItem
from apps.users.models import UserProfile
from apps.shops.models import Shop

class Review(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    review_id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='reviews')
    order_item = models.OneToOneField(OrderItem, on_delete=models.CASCADE, related_name='review')
    customer = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE)
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    title = models.CharField(max_length=255, null=True, blank=True)
    review_text = models.TextField(null=True, blank=True)
    is_verified_purchase = models.BooleanField(default=False)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Review for {self.product.product_name} by {self.customer.email}"

class ReviewImage(models.Model):
    image_id = models.BigAutoField(primary_key=True)
    review = models.ForeignKey(Review, on_delete=models.CASCADE, related_name='images')
    image_url = models.URLField(max_length=2048)
    alt_text = models.CharField(max_length=255, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class ReviewResponse(models.Model):
    response_id = models.BigAutoField(primary_key=True)
    review = models.OneToOneField(Review, on_delete=models.CASCADE, related_name='response')
    responder = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    response_text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class ReviewVote(models.Model):
    VOTE_TYPE_CHOICES = [
        ('helpful', 'Helpful'),
        ('not_helpful', 'Not Helpful'),
    ]

    vote_id = models.BigAutoField(primary_key=True)
    review = models.ForeignKey(Review, on_delete=models.CASCADE, related_name='votes')
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    vote_type = models.CharField(max_length=11, choices=VOTE_TYPE_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('review', 'user')

class ShopReview(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    shop_review_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='reviews')
    customer = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    order = models.ForeignKey(Order, on_delete=models.CASCADE)
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    title = models.CharField(max_length=255, null=True, blank=True)
    review_text = models.TextField(null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('shop', 'customer', 'order')

class RatingSummary(models.Model):
    summary_id = models.BigAutoField(primary_key=True)
    product = models.OneToOneField(Product, on_delete=models.CASCADE, null=True, blank=True, related_name='rating_summary')
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, null=True, blank=True, related_name='rating_summary')
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    total_reviews = models.PositiveIntegerField(default=0)
    rating_1_count = models.PositiveIntegerField(default=0)
    rating_2_count = models.PositiveIntegerField(default=0)
    rating_3_count = models.PositiveIntegerField(default=0)
    rating_4_count = models.PositiveIntegerField(default=0)
    rating_5_count = models.PositiveIntegerField(default=0)
    last_updated_at = models.DateTimeField()

    class Meta:
        constraints = [
            models.CheckConstraint(
                check=(models.Q(product__isnull=False) & models.Q(shop__isnull=True)) |
                      (models.Q(product__isnull=True) & models.Q(shop__isnull=False)),
                name='chk_summary_target'
            )
        ]

class ReviewModeration(models.Model):
    ACTION_CHOICES = [
        ('approve', 'Approve'),
        ('reject', 'Reject'),
        ('flag', 'Flag'),
        ('edit', 'Edit'),
    ]

    moderation_id = models.BigAutoField(primary_key=True)
    review = models.ForeignKey(Review, on_delete=models.CASCADE, related_name='moderation_history')
    moderator = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.DO_NOTHING)
    action = models.CharField(max_length=10, choices=ACTION_CHOICES)
    reason = models.TextField(null=True, blank=True)
    moderated_at = models.DateTimeField(auto_now_add=True)
