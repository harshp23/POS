/// An error the API returns to the client as-is.
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
  }
}

export const badRequest = (message: string, details?: unknown) => new ApiError(400, 'bad_request', message, details);
export const unauthorized = (message = 'Sign in required.') => new ApiError(401, 'unauthorized', message);
export const forbidden = (message: string) => new ApiError(403, 'forbidden', message);
export const notFound = (message: string) => new ApiError(404, 'not_found', message);
export const conflict = (message: string, details?: unknown) => new ApiError(409, 'conflict', message, details);
export const unprocessable = (message: string, details?: unknown) =>
  new ApiError(422, 'unprocessable', message, details);

/// A database error, carrying the Postgres / PostgREST error code.
export class DbError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly details?: string | null,
    readonly hint?: string | null,
  ) {
    super(message);
  }
}

/// Maps a database error onto an HTTP error without leaking internals.
export function fromDbError(e: DbError): ApiError {
  const details = { db_code: e.code, db_message: e.message, db_details: e.details ?? undefined };
  switch (e.code) {
    case '23505':
      return new ApiError(409, 'duplicate', 'A record with the same key already exists.', details);
    case '23503':
      return new ApiError(422, 'reference_missing', 'The record refers to something that does not exist (yet).', details);
    case '23502':
    case '23514':
    case '22P02':
    case '22001':
    case '22003':
    case '22007':
    case '22008':
      return new ApiError(422, 'invalid_value', 'A value was rejected by the database.', details);
    case '42501':
      return new ApiError(403, 'forbidden', 'Your role or organization does not allow this change.', details);
    case '42703':
    case '42P01':
    case 'PGRST204':
    case 'PGRST205':
      return new ApiError(
        500,
        'schema_mismatch',
        'The database is missing a table or column the backend expects. Has supabase/migrations/20260928_pos_vendor_backend.sql been run?',
        details,
      );
    case 'PGRST116':
      return new ApiError(404, 'not_found', 'Record not found.', details);
    case 'PGRST301':
    case 'PGRST302':
      return new ApiError(401, 'unauthorized', 'Your session has expired. Sign in again.', details);
    default:
      return new ApiError(500, 'database_error', 'The database could not complete the request.', details);
  }
}
