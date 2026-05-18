import type { NextFunction, Request, Response } from "express";

export class HttpError extends Error {
    readonly statusCode: number;

    constructor(statusCode: number, message: string) {
        super(message);
        this.statusCode = statusCode;
    }
}

export function asyncHandler(
    handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
    return (req: Request, res: Response, next: NextFunction): void => {
        void handler(req, res, next).catch(next);
    };
}

export function sendError(
    res: Response,
    statusCode: number,
    message: string,
): void {
    res.status(statusCode).json({
        error: message,
    });
}
