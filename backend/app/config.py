from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://financepro:financepro@localhost:5432/financepro"
    gemini_api_key: str = ""
    app_api_key: str = "dev-api-key"
    receipts_dir: str = "./receipts"
    base_currency: str = "USD"
    debug: bool = False


settings = Settings()
