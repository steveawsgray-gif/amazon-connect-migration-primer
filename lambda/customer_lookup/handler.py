"""Amazon Connect customer lookup — Project 2 data dip.

Connect invokes this synchronously from the Main Inbound flow with the caller's
endpoint in Details.ContactData.CustomerEndpoint.Address. The function reads one
DynamoDB item (keyed by E.164 phone number) and returns the flat STRING_MAP that
Connect flow blocks can consume: every value is a string, no nesting.

Contract:
  in : caller phone number (any common format; normalised to +1XXXXXXXXXX)
  out: customerFound, customerName, accountTier, routingQueue, openCase, caseId

Failure philosophy: a failed lookup must never fail the call. Any miss or error
returns routingQueue=General so the flow falls back to the staffed default queue.
"""
import os
import re

import boto3

TABLE_NAME = os.environ.get("CUSTOMER_TABLE", "")
_table = None


def _get_table():
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(TABLE_NAME)
    return _table


def _normalise(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if len(digits) == 11 and digits.startswith("1"):
        return "+" + digits
    if len(digits) == 10:
        return "+1" + digits
    return (phone or "").strip()


def _miss() -> dict:
    return {
        "customerFound": "false",
        "customerName": "",
        "accountTier": "Unknown",
        "routingQueue": "General",
        "openCase": "false",
        "caseId": "",
    }


def lambda_handler(event, context):
    contact = (event.get("Details") or {}).get("ContactData") or {}
    endpoint = contact.get("CustomerEndpoint") or {}
    phone = _normalise(endpoint.get("Address", ""))

    if not phone or not TABLE_NAME:
        return _miss()

    try:
        item = _get_table().get_item(Key={"phone_number": phone}).get("Item")
    except Exception:
        return _miss()

    if not item:
        return _miss()

    return {
        "customerFound": "true",
        "customerName": str(item.get("customer_name", "")),
        "accountTier": str(item.get("account_tier", "Standard")),
        "routingQueue": str(item.get("routing_queue", "General")),
        "openCase": str(item.get("open_case", "false")),
        "caseId": str(item.get("case_id", "")),
    }
