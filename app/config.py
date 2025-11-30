"""
Application Configuration

Uses Pydantic BaseSettings for environment-based configuration.
Configuration values can be overridden by:
1. Environment variables (highest priority)
2. .env file in the project root
3. Default values defined in this file (lowest priority)

To override settings, create a .env file in the project root with:
    ENV=production
    DATABASE_URL=postgresql://user:pass@localhost/dbname
    ALLOWED_ORIGINS=["https://yourapp.com"]
"""

import json
from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables and .env file.

    Attributes:
        ENV: Application environment (development, staging, production)
        DATABASE_URL: Database connection string (SQLite, PostgreSQL, etc.)
        ALLOWED_ORIGINS: CORS allowed origins for API requests
    """

    # Application environment
    ENV: str = "development"

    # Database configuration
    DATABASE_URL: str = "sqlite:///./lovers_compass.db"

    # CORS configuration
    # Can be set as JSON array string: '["http://localhost:3000"]'
    # or comma-separated: "http://localhost:3000,http://localhost:5173"
    ALLOWED_ORIGINS: str = '["*"]'

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"  # Ignore unknown environment variables
    )

    @property
    def allowed_origins_list(self) -> List[str]:
        """
        Parse ALLOWED_ORIGINS into a list.
        Supports JSON array format or comma-separated values.
        """
        try:
            # Try parsing as JSON array first
            return json.loads(self.ALLOWED_ORIGINS)
        except (json.JSONDecodeError, TypeError):
            # Fallback to comma-separated parsing
            if isinstance(self.ALLOWED_ORIGINS, str):
                return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]
            return ["*"]

    @property
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.ENV.lower() == "production"

    @property
    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.ENV.lower() == "development"


@lru_cache()
def get_settings() -> Settings:
    """
    Dependency function to get cached settings instance.

    Using lru_cache ensures settings are loaded only once and reused
    throughout the application lifecycle.

    Returns:
        Settings: Cached application settings instance
    """
    return Settings()
