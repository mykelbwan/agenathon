import { getAddress } from "ethers";

import { HttpError } from "./http";

export interface SpawnUrgencyInput {
  urgency: "low" | "medium" | "high";
}

export function requireNonEmptyString(
  value: unknown,
  fieldName: string,
): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpError(400, `${fieldName} must be a non-empty string`);
  }
  return value.trim();
}

export function requireUintString(
  value: unknown,
  fieldName: string,
): bigint {
  if (typeof value !== "string" && typeof value !== "number") {
    throw new HttpError(400, `${fieldName} must be a string or number`);
  }

  const normalized = String(value).trim();
  if (!/^\d+$/.test(normalized)) {
    throw new HttpError(400, `${fieldName} must be an unsigned integer`);
  }

  return BigInt(normalized);
}

export function requireUint8(value: unknown, fieldName: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0 || parsed > 255) {
    throw new HttpError(400, `${fieldName} must be an integer between 0 and 255`);
  }
  return parsed;
}

export function requirePositiveId(value: unknown, fieldName: string): bigint {
  const parsed = requireUintString(value, fieldName);
  if (parsed <= 0n) {
    throw new HttpError(400, `${fieldName} must be greater than zero`);
  }
  return parsed;
}

export function requireUrgency(value: unknown): SpawnUrgencyInput["urgency"] {
  if (value === undefined) {
    return "medium";
  }

  if (value === "low" || value === "medium" || value === "high") {
    return value;
  }

  throw new HttpError(400, "urgency must be one of: low, medium, high");
}

export function requireAddress(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new HttpError(400, `${fieldName} must be a string`);
  }

  try {
    return getAddress(value);
  } catch {
    throw new HttpError(400, `${fieldName} must be a valid address`);
  }
}
