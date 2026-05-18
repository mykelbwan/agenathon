import { Router } from "express";

import { asyncHandler } from "../lib/http";
import { requirePositiveId } from "../lib/validation";
import type { AuctionService } from "../services/auction-service";

export function createAuctionRouter(auctionService: AuctionService): Router {
    const router = Router();

    router.get(
        "/auctions",
        asyncHandler(async (_req, res) => {
            const auctions = await auctionService.listAuctions();
            res.json({ auctions });
        }),
    );

    router.get(
        "/auctions/:id",
        asyncHandler(async (req, res) => {
            const auctionId = requirePositiveId(req.params.id, "id");
            const auction = await auctionService.getAuctionById(auctionId);
            res.json({ auction });
        }),
    );

    return router;
}
