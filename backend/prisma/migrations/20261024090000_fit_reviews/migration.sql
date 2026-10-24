-- «تقييمات من بمقاسي» — reviews from women her size.
--
-- Purely additive. One enum, one table, five nullable columns on
-- `product_reviews`. No existing row is rewritten: an old review simply has
-- no fit, no size and no photographs, which is what it always had.
--
-- ## What is stored, and what deliberately is not
--
-- `fit_profiles` holds two facts she chooses to give — height and usual size —
-- and nothing else: no weight, no body shape, no measurements. It is read only
-- by her and by the review code at the moment she writes a review.
--
-- A review keeps a coarse snapshot of it — her height rounded down to a 5 cm
-- band (`height_band`) and her usual size — copied only when she agreed, and
-- never served to anyone. It exists so «من بمقاسي» can match the review to
-- women her size and the anonymous fit summary can count it. Reem's shoppers
-- are women in Syria; a named woman's body is not printed under her review.
--
-- `size_bought` is not typed by anyone. It is read from the variant of the
-- delivered order the review is attached to, so "true to size" always sits
-- beside the size that actually shipped.

-- CreateEnum
CREATE TYPE "ReviewFit" AS ENUM ('RUNS_SMALL', 'TRUE_TO_SIZE', 'RUNS_LARGE');

-- AlterTable
ALTER TABLE "product_reviews" ADD COLUMN     "fit" "ReviewFit",
ADD COLUMN     "height_band" INTEGER,
ADD COLUMN     "photo_urls" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "size_bought" VARCHAR(16),
ADD COLUMN     "usual_size" VARCHAR(8);

-- CreateTable
CREATE TABLE "fit_profiles" (
    "user_id" UUID NOT NULL,
    "height_cm" INTEGER,
    "usual_size" VARCHAR(8),
    "share_on_reviews" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "fit_profiles_pkey" PRIMARY KEY ("user_id")
);

-- AddForeignKey
ALTER TABLE "fit_profiles" ADD CONSTRAINT "fit_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

