# Cedarbridge-Ticketing
Project Overview

A cloud engineering project focused on designing, deploying, securing, and operating an internal IT ticket management system using Microsoft Azure. The solution aims to centralize IT requests, improve ticket ownership and status tracking, provide operational visibility, and support a consistent ticket lifecycle.

Project Objectives

Deliver a functioning IT ticketing application.
Design and deploy supporting Azure infrastructure.
Implement secure authentication and authorization.
Use Terraform for Infrastructure as Code.
Implement automated testing and CI/CD.
Establish monitoring, logging, and recovery capabilities.

Project Documentation

Business Context
Acceptance Criteria
ITSM Workflow
Ticket Data Model
Architecture Diagram
Open Decisions


Technology Stack

Cloud Platform: Microsoft Azure
Infrastructure as Code: Terraform
Source Control: GitHub
CI/CD: GitHub Actions
Application Hosting: To be determined
Database: To be determined
Identity: To be determined

## Local Application Setup

Cedarbridge is an internal IT ticketing application
built using Python, FastAPI and HTML.

### Running Locally

1. Navigate to the App directory:

   cd App

2. Create a virtual environment:

   py -m venv .venv

3. Activate the environment:

   .\.venv\Scripts\Activate.ps1

4. Install dependencies:

   python -m pip install -r requirements.txt

5. Start the application:

   python -m uvicorn Main:app --reload

6. Open http://127.0.0.1:8000

### Current Functionality

- Submit IT support tickets
- Validate required information
- Generate unique ticket IDs and timestamps
- Retrieve tickets by their ID
- Temporarily store tickets in memory

### Limitations

Tickets disappear when the application restarts.
Azure SQL integration and Entra ID authentication
have not yet been implemented.