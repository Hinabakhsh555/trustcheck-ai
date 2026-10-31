"""Azure Functions entry point for TrustCheck's FastAPI application."""
import azure.functions as func
from backend.app import app

main = func.AsgiFunctionApp(app=app, http_auth_level=func.AuthLevel.ANONYMOUS)
