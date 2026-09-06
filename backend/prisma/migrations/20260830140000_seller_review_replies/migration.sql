-- A seller could read every review of her and answer none of them.
--
-- On a marketplace the reply matters more than the rating: a customer reading
-- «القياس صغير» learns something different when the seller has written
-- «صحيح، الموديل ضيّق — خذي مقاساً أكبر» underneath it. Without somewhere to
-- put that, the only remedy a seller had for an unfair review was to ask a
-- moderator to remove it.
--
-- The reply is a column on the review rather than a row of its own: there is
-- at most one, it belongs to whoever is being reviewed, and it is edited in
-- place. A thread would imply a conversation the platform does not moderate.
ALTER TABLE "product_reviews"
  ADD COLUMN "seller_reply" TEXT,
  ADD COLUMN "seller_replied_at" TIMESTAMP(3);

ALTER TABLE "seller_reviews"
  ADD COLUMN "seller_reply" TEXT,
  ADD COLUMN "seller_replied_at" TIMESTAMP(3);
