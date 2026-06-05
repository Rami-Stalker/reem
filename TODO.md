- [x] Inspect backend product routes and identify protected read endpoints.
- [x] Patch backend so catalog GET endpoints are public (remove requireAuth from read routes).
- [x] Update backend serialization to not require req.user for public responses (set isLiked=false when unauthenticated).
- [ ] Ensure homepage/home/products by category/search/trending/new arrivals/featured/most-loved/top-rated all return data without auth.
- [ ] Run backend tests/lint or start server and verify endpoints return 200 without Authorization header.


