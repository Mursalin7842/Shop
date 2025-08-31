from django.db import models
from apps.users.models import UserProfile
from apps.products.models import Product
from apps.shops.models import Shop
from apps.orders.models import Order

class AnalyticsEvent(models.Model):
    event_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.SET_NULL, null=True, blank=True)
    session_id = models.CharField(max_length=255, null=True, blank=True)
    event_type = models.CharField(max_length=100)
    event_data_json = models.JSONField(null=True, blank=True)
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True, blank=True)
    shop = models.ForeignKey(Shop, on_delete=models.SET_NULL, null=True, blank=True)
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=512, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class DailySalesReport(models.Model):
    report_id = models.BigAutoField(primary_key=True)
    report_date = models.DateField()
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True)
    total_orders = models.PositiveIntegerField()
    total_revenue = models.DecimalField(max_digits=15, decimal_places=2)
    total_commission = models.DecimalField(max_digits=15, decimal_places=2)
    average_order_value = models.DecimalField(max_digits=15, decimal_places=2)
    new_customers = models.PositiveIntegerField()
    returning_customers = models.PositiveIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('report_date', 'shop')

class ProductAnalytics(models.Model):
    analytics_id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    date = models.DateField()
    views = models.PositiveIntegerField(default=0)
    clicks = models.PositiveIntegerField(default=0)
    add_to_cart = models.PositiveIntegerField(default=0)
    purchases = models.PositiveIntegerField(default=0)
    revenue = models.DecimalField(max_digits=15, decimal_places=2, default=0.00)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('product', 'date')

class ShopPerformance(models.Model):
    performance_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE)
    date = models.DateField()
    orders_count = models.PositiveIntegerField()
    revenue = models.DecimalField(max_digits=15, decimal_places=2)
    commission_paid = models.DecimalField(max_digits=15, decimal_places=2)
    average_rating = models.DecimalField(max_digits=3, decimal_places=2)
    response_time_hours = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('shop', 'date')

class UserBehaviorAnalytics(models.Model):
    behavior_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    date = models.DateField()
    pages_viewed = models.PositiveIntegerField()
    time_spent_minutes = models.PositiveIntegerField()
    products_viewed = models.PositiveIntegerField()
    searches_made = models.PositiveIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'date')

class PlatformMetric(models.Model):
    metric_id = models.BigAutoField(primary_key=True)
    metric_date = models.DateField(unique=True)
    total_users = models.PositiveIntegerField()
    active_users = models.PositiveIntegerField()
    total_shops = models.PositiveIntegerField()
    active_shops = models.PositiveIntegerField()
    total_orders = models.PositiveIntegerField()
    total_revenue = models.DecimalField(max_digits=18, decimal_places=2)
    platform_commission = models.DecimalField(max_digits=18, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

class CustomReport(models.Model):
    report_id = models.BigAutoField(primary_key=True)
    report_name = models.CharField(max_length=255)
    report_type = models.CharField(max_length=100)
    filters_json = models.JSONField()
    created_by = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    last_run_at = models.DateTimeField(null=True, blank=True)

class ReportSchedule(models.Model):
    FREQUENCY_CHOICES = [
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    ]

    schedule_id = models.BigAutoField(primary_key=True)
    report = models.ForeignKey(CustomReport, on_delete=models.CASCADE)
    frequency = models.CharField(max_length=10, choices=FREQUENCY_CHOICES)
    recipients_json = models.JSONField()
    next_run_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
