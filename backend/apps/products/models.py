from django.db import models
from apps.shops.models import Shop

class Category(models.Model):
    category_id = models.BigAutoField(primary_key=True)
    parent_category = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='child_categories')
    category_name = models.CharField(max_length=255)
    category_slug = models.SlugField(max_length=255, unique=True)
    description = models.TextField(null=True, blank=True)
    image_url = models.URLField(max_length=2048, null=True, blank=True)
    commission_rate_override = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.category_name

class Product(models.Model):
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('archived', 'Archived'),
    ]

    product_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='products')
    category = models.ForeignKey(Category, on_delete=models.RESTRICT, related_name='products')
    product_name = models.CharField(max_length=255)
    product_slug = models.SlugField(max_length=255)
    description = models.TextField(null=True, blank=True)
    short_description = models.CharField(max_length=512, null=True, blank=True)
    sku = models.CharField(max_length=100, null=True, blank=True)
    brand = models.CharField(max_length=100, null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='draft')
    featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [('shop', 'product_slug'), ('shop', 'sku')]

    def __str__(self):
        return self.product_name

class ProductVariant(models.Model):
    variant_id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variants')
    variant_name = models.CharField(max_length=255, null=True, blank=True)
    sku = models.CharField(max_length=100, null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    compare_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    weight = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    dimensions_json = models.JSONField(null=True, blank=True)
    barcode = models.CharField(max_length=100, null=True, blank=True)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('product', 'sku')

    def __str__(self):
        return f"{self.product.product_name} - {self.variant_name or self.sku}"

class ProductAttribute(models.Model):
    ATTRIBUTE_TYPE_CHOICES = [
        ('text', 'Text'),
        ('number', 'Number'),
        ('boolean', 'Boolean'),
        ('select', 'Select'),
    ]

    attribute_id = models.BigAutoField(primary_key=True)
    attribute_name = models.CharField(max_length=100, unique=True)
    attribute_type = models.CharField(max_length=10, choices=ATTRIBUTE_TYPE_CHOICES, default='text')
    is_required = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.attribute_name

class ProductAttributeValue(models.Model):
    value_id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='attribute_values')
    attribute = models.ForeignKey(ProductAttribute, on_delete=models.CASCADE)
    attribute_value = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('product', 'attribute')

    def __str__(self):
        return f"{self.product.product_name} - {self.attribute.attribute_name}: {self.attribute_value}"

class ProductImage(models.Model):
    image_id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='images')
    variant = models.ForeignKey(ProductVariant, on_delete=models.SET_NULL, null=True, blank=True, related_name='images')
    image_url = models.URLField(max_length=2048)
    alt_text = models.CharField(max_length=255, null=True, blank=True)
    sort_order = models.IntegerField(default=0)
    is_primary = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image for {self.product.product_name}"

class ProductInventory(models.Model):
    inventory_id = models.BigAutoField(primary_key=True)
    variant = models.OneToOneField(ProductVariant, on_delete=models.CASCADE, related_name='inventory')
    quantity_available = models.IntegerField(default=0)
    quantity_reserved = models.IntegerField(default=0)
    reorder_level = models.IntegerField(null=True, blank=True)
    supplier_info_json = models.JSONField(null=True, blank=True)
    last_updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Inventory for {self.variant}"

class ProductReviewsSummary(models.Model):
    summary_id = models.BigAutoField(primary_key=True)
    product = models.OneToOneField(Product, on_delete=models.CASCADE, related_name='reviews_summary')
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    total_reviews = models.PositiveIntegerField(default=0)
    rating_distribution_json = models.JSONField(null=True, blank=True)
    last_updated_at = models.DateTimeField()

    def __str__(self):
        return f"Reviews summary for {self.product.product_name}"
