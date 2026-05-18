import { Router } from "express";

import { asyncHandler } from "../lib/http";
import {
    requireNonEmptyString,
    requireUint8,
    requireUintString,
} from "../lib/validation";
import type {
    AuctionService,
    CreateAuctionInput,
} from "../services/auction-service";

export function createProviderRouter(auctionService: AuctionService): Router {
    const router = Router();

    router.post(
        "/provider/auction",
        asyncHandler(async (req, res) => {
            const body = req.body as Record<string, unknown>;

            const input: CreateAuctionInput = {
                dataType: requireNonEmptyString(body.dataType, "dataType"),
                apiUrl: requireNonEmptyString(body.apiUrl, "apiUrl"),
                jsonSelector: requireNonEmptyString(
                    body.jsonSelector,
                    "jsonSelector",
                ),
                decimals: requireUint8(body.decimals, "decimals"),
                startPrice: requireUintString(body.startPrice, "startPrice"),
                floorPrice: requireUintString(body.floorPrice, "floorPrice"),
                priceStep: requireUintString(body.priceStep, "priceStep"),
                timeoutBlocks: requireUintString(
                    body.timeoutBlocks,
                    "timeoutBlocks",
                ),
            };

            const result = await auctionService.createAuction(input);
            res.status(201).json(result);
        }),
    );

    return router;
}
