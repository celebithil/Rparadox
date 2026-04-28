#ifndef __PX_HEAD_H__
#define __PX_HEAD_H__
pxhead_t *get_px_head(pxdoc_t *pxdoc, pxstream_t *pxs);





int get_datablock_head(pxdoc_t *pxdoc, pxstream_t *pxs, int datablocknr, TDataBlock *datablockhead);

mbhead_t *get_mb_head(pxblob_t *pxblob, pxstream_t *pxs);

#endif
