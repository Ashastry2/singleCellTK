library(singleCellTK)
library(ggplot2)

test_that(desc = "Testing plotBubble.R", {
  data("scExample")
  
  bubblePlot <- plotBubble(sce, useAssay="counts", feature="B2M", displayName="feature_name", groupNames="type", title="cluster test")
  
  testthat::expect_true(is.ggplot(bubblePlot))
})
test_that(desc = "plotSCEHeatmap scales features (rows), not cells", {
    # Regression test. `scale` is documented as acting "on each row", but
    # base::scale() standardizes columns, so the default scale = TRUE z-scored
    # each cell across genes instead of each gene across cells. It did not
    # error -- it drew the wrong picture.
    data("scExample")
    sce <- subsetSCECols(sce, colData = "type != 'EmptyDroplet'")
    sce <- runNormalization(sce, useAssay = "counts",
                            outAssayName = "logcounts",
                            normalizationMethod = "logNormCounts")
    sub <- sce[seq_len(20), seq_len(15)]

    m <- plotSCEHeatmap(sub, useAssay = "logcounts", scale = TRUE)@matrix
    # rows (features) are centred; columns (cells) are not
    expect_true(all(abs(rowMeans(m, na.rm = TRUE)) < 1e-8))
    expect_false(all(abs(colMeans(m, na.rm = TRUE)) < 1e-8))

    # The documented "min-max" spelling was never matched -- the code only
    # tested for "min_max" -- so that option silently did nothing.
    for (spelling in c("min-max", "min_max")) {
        mm <- plotSCEHeatmap(sub, useAssay = "logcounts", scale = spelling)@matrix
        expect_true(all(abs(apply(mm, 1, min, na.rm = TRUE)) < 1e-9))
        expect_true(all(abs(apply(mm, 1, max, na.rm = TRUE) - 1) < 1e-9))
    }
})
