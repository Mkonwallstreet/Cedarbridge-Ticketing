
from pathlib import Path
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import FastAPI, Form, HTTPException
from fastapi.responses import FileResponse

app = FastAPI(title="Cedarbridge IT Support")

# Temporary in-memory ticket storage
tickets = {}


# Display the employee webpage
@app.get("/")
def home():
    return FileResponse(Path(__file__).with_name("index.html"))


# Receive and create a new ticket
@app.post("/tickets")
def submit_ticket(
    requester_name: str = Form(...),
    requester_email: str = Form(...),
    category: str = Form(...),
    description: str = Form(...)
):
    # Clean submitted information
    requester_name = requester_name.strip()
    requester_email = requester_email.strip()
    category = category.strip().lower()
    description = description.strip()

    # Validate required fields
    if not all([requester_name, requester_email, category, description]):
        raise HTTPException(
            status_code=422,
            detail="All ticket fields are required."
        )

    # Validate selected category
    allowed_categories = {
        "hardware", "software", "network", "access", "other"
    }

    if category not in allowed_categories:
        raise HTTPException(
            status_code=422,
            detail="Invalid ticket category."
        )

    # Generate a ticket reference
    ticket_id = f"CB-{uuid4().hex[:12].upper()}"

    while ticket_id in tickets:
        ticket_id = f"CB-{uuid4().hex[:12].upper()}"

    # Create ticket record
    ticket = {
        "ticket_id": ticket_id,
        "requester_name": requester_name,
        "requester_email": requester_email,
        "category": category,
        "description": description,
        "status": "Submitted",
        "priority": "Unassessed",
        "created_at": datetime.now(timezone.utc).isoformat()
    }

    # Store ticket temporarily
    tickets[ticket_id] = ticket

    return {
        "message": "Ticket created successfully",
        "ticket": ticket
    }

# Retrieve a ticket using its ID
@app.get("/tickets/{ticket_id}")
def get_ticket(ticket_id: str):

    # Search for the ticket in memory
    ticket = tickets.get(ticket_id)

    # Handle tickets that don't exist
    if ticket is None:
        raise HTTPException(
            status_code=404,
            detail="Ticket not found"
        )

    # Return the ticket information
    return {
        "ticket_id": ticket["ticket_id"],
        "category": ticket["category"],
        "description": ticket["description"],
        "status": ticket["status"],
        "priority": ticket["priority"],
        "created_at": ticket["created_at"]
    }
