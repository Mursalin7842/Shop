from django.db import models
from apps.users.models import UserProfile

class AuditLog(models.Model):
    log_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=255)
    resource_type = models.CharField(max_length=100, null=True, blank=True)
    resource_id = models.CharField(max_length=255, null=True, blank=True)
    old_values_json = models.JSONField(null=True, blank=True)
    new_values_json = models.JSONField(null=True, blank=True)
    ip_address = models.GenericIPAddressField()
    user_agent = models.CharField(max_length=512, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

class SecurityLog(models.Model):
    EVENT_TYPE_CHOICES = [
        ('login', 'Login'),
        ('logout', 'Logout'),
        ('failed_login', 'Failed Login'),
        ('password_change', 'Password Change'),
        ('suspicious_activity', 'Suspicious Activity'),
        ('permission_change', 'Permission Change'),
    ]

    log_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.SET_NULL, null=True, blank=True)
    event_type = models.CharField(max_length=20, choices=EVENT_TYPE_CHOICES)
    ip_address = models.GenericIPAddressField()
    user_agent = models.CharField(max_length=512, null=True, blank=True)
    success = models.BooleanField()
    failure_reason = models.CharField(max_length=255, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

class DataChangeLog(models.Model):
    OPERATION_CHOICES = [
        ('INSERT', 'Insert'),
        ('UPDATE', 'Update'),
        ('DELETE', 'Delete'),
    ]

    change_id = models.BigAutoField(primary_key=True)
    table_name = models.CharField(max_length=100)
    record_id = models.CharField(max_length=255)
    operation = models.CharField(max_length=10, choices=OPERATION_CHOICES)
    changed_by = models.CharField(max_length=255, null=True, blank=True)
    old_data_json = models.JSONField(null=True, blank=True)
    new_data_json = models.JSONField(null=True, blank=True)
    changed_at = models.DateTimeField(auto_now_add=True)

class LoginHistory(models.Model):
    login_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    ip_address = models.GenericIPAddressField()
    user_agent = models.CharField(max_length=512, null=True, blank=True)
    location_json = models.JSONField(null=True, blank=True)
    login_method = models.CharField(max_length=50, null=True, blank=True)
    success = models.BooleanField()
    failure_reason = models.CharField(max_length=255, null=True, blank=True)
    attempted_at = models.DateTimeField(auto_now_add=True)

class ApiAccessLog(models.Model):
    log_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.SET_NULL, null=True, blank=True)
    endpoint = models.CharField(max_length=512)
    method = models.CharField(max_length=10)
    request_data_json = models.JSONField(null=True, blank=True)
    response_status = models.IntegerField(null=True, blank=True)
    response_time_ms = models.IntegerField(null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

class SecurityIncident(models.Model):
    SEVERITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]

    incident_id = models.BigAutoField(primary_key=True)
    incident_type = models.CharField(max_length=100)
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES)
    description = models.TextField()
    affected_users_json = models.JSONField(null=True, blank=True)
    detected_at = models.DateTimeField()
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolution_notes = models.TextField(null=True, blank=True)

class SystemBackup(models.Model):
    BACKUP_TYPE_CHOICES = [
        ('full', 'Full'),
        ('incremental', 'Incremental'),
        ('database', 'Database'),
        ('filesystem', 'Filesystem'),
    ]
    STATUS_CHOICES = [
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    backup_id = models.BigAutoField(primary_key=True)
    backup_type = models.CharField(max_length=20, choices=BACKUP_TYPE_CHOICES)
    file_path = models.CharField(max_length=2048)
    file_size = models.BigIntegerField(null=True, blank=True)
    backup_started_at = models.DateTimeField()
    backup_completed_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES)
    checksum = models.CharField(max_length=255, null=True, blank=True)

class ComplianceReport(models.Model):
    report_id = models.BigAutoField(primary_key=True)
    report_type = models.CharField(max_length=100)
    period_start = models.DateField()
    period_end = models.DateField()
    report_data_json = models.JSONField()
    generated_at = models.DateTimeField(auto_now_add=True)
