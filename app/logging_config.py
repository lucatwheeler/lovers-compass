"""
Logging Configuration

Centralized logging setup for the application with privacy-conscious
defaults. Configured to avoid logging sensitive data like raw request
bodies or precise location coordinates.

The logging configuration can be extended in the future to:
- Add custom formatters that redact coordinates from logs
- Integrate with external logging services (e.g., CloudWatch, Datadog)
- Add structured JSON logging for production environments
"""

import logging
import sys
from typing import Optional

from app.config import get_settings

settings = get_settings()


class SensitiveDataFilter(logging.Filter):
    """
    Filter to prevent logging of sensitive data patterns.

    This filter can be extended to redact:
    - Location coordinates (latitude/longitude)
    - Device IDs or couple IDs in certain contexts
    - Request/response bodies containing personal data
    """

    def filter(self, record: logging.LogRecord) -> bool:
        """
        Filter log records to prevent sensitive data exposure.

        Currently allows all records through. In future phases, this can
        be extended to detect and redact sensitive patterns.

        Args:
            record: The log record to filter

        Returns:
            bool: True to allow the record, False to suppress it
        """
        # Future enhancement: Add pattern matching to redact coordinates
        # Example:
        # if hasattr(record, 'msg'):
        #     record.msg = re.sub(r'latitude":\s*-?\d+\.\d+', 'latitude": [REDACTED]', str(record.msg))
        #     record.msg = re.sub(r'longitude":\s*-?\d+\.\d+', 'longitude": [REDACTED]', str(record.msg))

        return True


def setup_logging(log_level: Optional[str] = None) -> None:
    """
    Configure application logging with appropriate handlers and formatters.

    Sets up:
    - Console output with colored formatting (development)
    - Root logger configuration
    - Integration with Uvicorn/FastAPI logs
    - Sensitive data filtering

    Args:
        log_level: Optional log level override. If not provided, uses
                   INFO for production, DEBUG for development.
    """
    # Determine log level based on environment
    if log_level is None:
        log_level = "DEBUG" if settings.is_development else "INFO"

    # Convert string to logging constant
    numeric_level = getattr(logging, log_level.upper(), logging.INFO)

    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(numeric_level)

    # Create formatter
    if settings.is_development:
        # Detailed format for development
        formatter = logging.Formatter(
            fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
    else:
        # Simpler format for production (can be changed to JSON later)
        formatter = logging.Formatter(
            fmt="%(asctime)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )

    console_handler.setFormatter(formatter)

    # Add sensitive data filter
    sensitive_filter = SensitiveDataFilter()
    console_handler.addFilter(sensitive_filter)

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)
    root_logger.addHandler(console_handler)

    # Configure Uvicorn loggers to use our configuration
    # Prevents duplicate log entries and ensures consistent formatting
    logging.getLogger("uvicorn").handlers.clear()
    logging.getLogger("uvicorn").addHandler(console_handler)
    logging.getLogger("uvicorn.access").handlers.clear()
    logging.getLogger("uvicorn.access").addHandler(console_handler)

    # Reduce SQLAlchemy logging verbosity in production
    # (database queries logged at INFO level in development via engine.echo)
    if not settings.is_development:
        logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    # Log initial setup message
    logging.info(f"Logging configured - Level: {log_level}, Environment: {settings.ENV}")


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance for a specific module.

    Usage:
        from app.logging_config import get_logger
        logger = get_logger(__name__)
        logger.info("Something happened")

    Args:
        name: Logger name (typically __name__ of the module)

    Returns:
        logging.Logger: Configured logger instance
    """
    return logging.getLogger(name)
