# helper-long-fixture.R
#
# Generates a minimal Paradox 3.0 table (.db) with a single Long field in
# tempdir(). Used by test-long-fields.R to exercise extreme Long values.
#
# Rationale: the bundled corpora contain only one negative Long value
# (-40 in TypSammlung.DB, checked implicitly by a golden-file comparison),
# which is not enough to pin down the sign handling of get_long_be()
# (src/px_misc.c). Before the 0.3.1 fix, get_long_be() zero-extended the
# 32-bit word, so every negative Long was returned as value + 2^32
# (e.g. -1 -> 4294967295). These fixtures make the boundary values
# explicitly testable without adding binary fixtures to the repository.
#
# File layout (see src/fileformat.h, read by get_px_head() in src/px_head.c):
#   - 88-byte TPxHeader, all fields byte-aligned little-endian
#   - 1 field descriptor TFldInfoRec (fType = pxfLong = 0x04, fSize = 4)
#   - tableNamePtr (4 bytes, skipped)
#   - field name pointer array (4 bytes, skipped for fileType = 0)
#   - tableName (79 bytes), null-terminated field name
#   - zero padding up to headerSize (2048)
#   - one 1024-byte data block: TDataBlock header (6 bytes) + records
#
# Paradox stores Long values biased: on disk a value is kept as
# value + 2^31 (mod 2^32) as a big-endian 32-bit word. The bit pattern
# 0x00000000 (which would decode to -2^31) is reported as NULL by pxlib,
# so -2147483648 is not representable and must be passed as NA.

make_long_db <- function(values, name = "longbound.db") {
  values <- as.integer(values)
  n <- length(values)
  stopifnot(n >= 1L, n <= 254L) # one record must fit into a 1024-byte block
  path <- file.path(tempdir(), name)

  # --- header (88 bytes) -------------------------------------------------
  hdr <- raw(88)
  patch <- function(offset, bytes) hdr[offset + seq_along(bytes)] <<- bytes
  w16le <- function(v) writeBin(as.integer(v), raw(), size = 2, endian = "little")
  w32le <- function(v) writeBin(as.integer(v), raw(), size = 4, endian = "little")

  patch(0,  w16le(4))   # recordSize: one Long field = 4 bytes
  patch(2,  w16le(2048))# headerSize: data blocks start at 2048
  patch(4,  as.raw(0))  # fileType = pxfFileTypIndexDB
  patch(5,  as.raw(1))  # maxTableSize = 1 -> 1024-byte data blocks
  patch(6,  w32le(n))   # numRecords
  patch(12, w16le(1))   # fileBlocks
  patch(14, w16le(1))   # firstBlock
  patch(16, w16le(1))   # lastBlock
  patch(33, w16le(1))   # numFields
  patch(57, as.raw(3))  # fileVersionID = 3.0 (no TPxDataHeader follows)
  patch(58, w16le(1))   # maxBlocks

  # --- field area ---------------------------------------------------------
  field_info <- as.raw(c(0x04, 0x04))         # fType = pxfLong, fSize = 4
  table_ptr  <- raw(4)                        # skipped tableNamePtr
  fname_ptrs <- raw(4)                        # skipped fieldNamePtrArray
  table_name <- c(charToRaw("longbound"), raw(79 - 9L))
  field_name <- c(charToRaw("value"), as.raw(0))

  head_area <- c(hdr, field_info, table_ptr, fname_ptrs, table_name, field_name)
  head_area <- c(head_area, raw(2048 - length(head_area)))

  # --- data block (1024 bytes) -------------------------------------------
  # On disk: value + 2^31 (mod 2^32), i.e. the sign bit flipped, written
  # as a big-endian 32-bit word. NA is stored as 0x00000000 and reads
  # back as NA.
  # NB: 0x80000000 is NA_INTEGER in R (INT_MIN is reserved for NA), so
  # the biased value cannot be built with integer arithmetic; extract
  # the four bytes from an exact double instead.
  records <- raw(4 * n)
  for (i in seq_len(n)) {
    if (is.na(values[i])) next              # stays 0x00000000
    u <- values[i] + 2147483648             # biased value, exact in [0, 2^32)
    records[(4 * i - 3):(4 * i)] <- as.raw(c(
      (u %/% 16777216) %% 256,
      (u %/% 65536)    %% 256,
      (u %/% 256)      %% 256,
       u               %% 256
    ))
  }
  block_head <- c(w16le(0), w16le(0), w16le((n - 1L) * 4L)) # next, prev, addDataSize
  block <- c(block_head, records)
  block <- c(block, raw(1024 - length(block)))

  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(c(head_area, block), con)
  path
}
