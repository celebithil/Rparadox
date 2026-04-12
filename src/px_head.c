#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "paradox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <time.h>
#include "pxversion.h"
#include "px_intern.h"
#include "px_memory.h"
#include "px_io.h"
#include "px_error.h"
#include "px_misc.h"

/* TMPBUFFSIZE must be larger than 261 because the tablename must fit into
 * the buffer. It is also the maximum length of a field name. Field names
 * which are longer get cut off.
 */
#define TMPBUFFSIZE 300
/* get_px_head() {{{
 * get the header info from the file
 * basic header info & field descriptions
 */
pxhead_t *get_px_head(pxdoc_t *pxdoc, pxstream_t *pxs)
{
	pxhead_t *pxh;
	TPxHeader pxhead;
	TPxDataHeader pxdatahead;
	TFldInfoRec pxinfo;
	pxfield_t *pfield;
	char dummy[TMPBUFFSIZE], c;
	int ret, i, j, tablenamelen;

	if((pxh = (pxhead_t *) pxdoc->malloc(pxdoc, sizeof(pxhead_t), _("Allocate memory for document header."))) == NULL) {
		px_error(pxdoc, PX_RuntimeError, _("Could not allocate memory for document header."));
		return NULL;
	}
	memset(pxh, 0, sizeof(pxhead_t));
	if(pxdoc->seek(pxdoc, pxs, 0, SEEK_SET) < 0)
		return NULL;
	if((ret = (int)pxdoc->read(pxdoc, pxs, sizeof(TPxHeader), &pxhead)) != sizeof(TPxHeader)) {
		px_error(pxdoc, PX_RuntimeError, _("Could not read header from paradox file."));
		pxdoc->free(pxdoc, pxh);
		return NULL;
	}

	/* check some header fields for reasonable values */
	if(pxhead.fileType > 8) {
		pxdoc->free(pxdoc, pxh);
		px_error(pxdoc, PX_RuntimeError, _("Paradox file has unknown file type (%d)."), pxhead.fileType);
		return NULL;
	}
	if(pxhead.maxTableSize > 32 || pxhead.maxTableSize < 1) {
		pxdoc->free(pxdoc, pxh);
		px_error(pxdoc, PX_RuntimeError, _("Paradox file has unknown table size (%d)."), pxhead.maxTableSize);
		return NULL;
	}
	if(pxhead.fileVersionID > 15 || pxhead.fileVersionID < 3) {
		pxdoc->free(pxdoc, pxh);
		px_error(pxdoc, PX_RuntimeError, _("Paradox file has unknown file version (0x%X)."), pxhead.fileVersionID);
		return NULL;
	}

	pxh->px_recordsize = get_short_le((const char *)&pxhead.recordSize);
	if(pxh->px_recordsize == 0) {
		pxdoc->free(pxdoc, pxh);
		px_error(pxdoc, PX_RuntimeError, _("Paradox file has zero record size."));
		return NULL;
	}
	pxh->px_headersize = get_short_le((const char *)&pxhead.headerSize);
	if(pxh->px_headersize == 0) {
		pxdoc->free(pxdoc, pxh);
		px_error(pxdoc, PX_RuntimeError, _("Paradox file has zero header size."));
		return NULL;
	}
	pxh->px_filetype = pxhead.fileType;
	pxh->px_numrecords = get_long_le((const char *)&pxhead.numRecords);
	pxh->px_numfields = get_short_le((const char *)&pxhead.numFields);
	pxh->px_fileblocks = get_short_le((const char *)&pxhead.fileBlocks);
	pxh->px_firstblock = get_short_le((const char *)&pxhead.firstBlock);
	pxh->px_lastblock = get_short_le((const char *)&pxhead.lastBlock);
	switch(pxhead.fileVersionID) {
		case 3:
			pxh->px_fileversion = 30;
			tablenamelen = 79;
			break;
		case 4:
			pxh->px_fileversion = 35;
			tablenamelen = 79;
			break;
		case 5:
		case 6:
		case 7:
		case 8:
		case 9:
			pxh->px_fileversion = 40;
			tablenamelen = 79;
			break;
		case 10:
		case 11:
			pxh->px_fileversion = 50;
			tablenamelen = 79;
			break;
		case 12:
			pxh->px_fileversion = 70;
			tablenamelen = 261;
			break;
		default:
			pxh->px_fileversion = 0;
			tablenamelen = 79;
	}
	pxh->px_indexfieldnumber = pxhead.indexFieldNumber;
	pxh->px_indexroot = get_short_le((const char *)&pxhead.indexRoot);
	pxh->px_numindexlevels = pxhead.numIndexLevels;
	pxh->px_writeprotected = pxhead.writeProtected;
	pxh->px_modifiedflags1 = pxhead.modifiedFlags1;
	pxh->px_modifiedflags2 = pxhead.modifiedFlags2;
	pxh->px_primarykeyfields = get_short_le((const char *)&pxhead.primaryKeyFields);

	if(((pxh->px_filetype == pxfFileTypIndexDB) ||
		  (pxh->px_filetype == pxfFileTypNonIndexDB) ||
		  (pxh->px_filetype == pxfFileTypNonIncSecIndex) ||
		  (pxh->px_filetype == pxfFileTypIncSecIndex) ||
          (pxh->px_filetype == pxfFileTypNonIncSecIndexG) ||
		  (pxh->px_filetype == pxfFileTypIncSecIndexG)) &&
		  (pxh->px_fileversion >= 40)) {
		if((ret = (int)pxdoc->read(pxdoc, pxs, sizeof(TPxDataHeader), &pxdatahead)) != sizeof(TPxDataHeader)) {
			pxdoc->free(pxdoc, pxh);
			return NULL;
		}
		pxh->px_doscodepage = get_short_le((const char *)&pxdatahead.dosCodePage);
		pxh->px_fileupdatetime = get_long_le((const char *)&pxdatahead.fileUpdateTime);
	} else {
		pxh->px_fileupdatetime = 0;
	}

	pxh->px_maxtablesize = pxhead.maxTableSize;
	pxh->px_sortorder = pxhead.sortOrder;
	pxh->px_refintegrity = pxhead.refIntegrity;
	pxh->px_autoinc = get_long_le((const char *)&pxhead.autoInc);

	pxh->px_encryption = get_long_le((const char*)&pxhead.encryption1);
	if ((pxh->px_encryption & 0xFFFFFFFF) == 0xFF00FF00) {
		pxh->px_encryption = get_long_le((const char*)&pxdatahead.encryption2);
	}

	/* The theoretical number of records is calculated from the number
	 * of data blocks and the number of records that fit into a data
	 * block. The 'TDataBlock' is decreasing the available space of the data
	 * block due to its header, which takes up 6 Bytes.
	 */
	pxh->px_theonumrecords = pxh->px_fileblocks * (int) ((pxh->px_maxtablesize*0x400-sizeof(TDataBlock)) / pxh->px_recordsize);

	if((pxh->px_fields = (pxfield_t *) pxdoc->malloc(pxdoc, pxh->px_numfields*sizeof(pxfield_t), _("Could not get memory for field definitions."))) == NULL)
		return NULL;

	pfield = pxh->px_fields;
	for(i=0; i<pxh->px_numfields; i++) {
		if((ret = (int)pxdoc->read(pxdoc, pxs, sizeof(TFldInfoRec), &pxinfo)) != sizeof(TFldInfoRec)) {
			pxdoc->free(pxdoc, pxh->px_fields);
			pxdoc->free(pxdoc, pxh);
			return NULL;
		}
		pfield->px_ftype = pxinfo.fType;
		if(pfield->px_ftype == pxfBCD) {
			pfield->px_flen = 17;
			pfield->px_fdc = pxinfo.fSize;
		} else {
			pfield->px_flen = pxinfo.fSize;
			pfield->px_fdc = 0;
		}
		pfield++;
	}

	/* skip the tableNamePtr */
	if((ret = (int)pxdoc->read(pxdoc, pxs, sizeof(int), dummy)) != sizeof(int)) {
		pxdoc->free(pxdoc, pxh->px_fields);
		pxdoc->free(pxdoc, pxh);
		return NULL;
	}

	/* skip the tfieldNamePtrArray, not present in primary index files */
	if(pxhead.fileType == 0 || pxhead.fileType == 2 ||
	   pxhead.fileType == 3 || pxhead.fileType == 5 ||
	   pxhead.fileType == 6 || pxhead.fileType == 8) {
		for(i=0; i<pxh->px_numfields; i++) {
			if((ret = (int)pxdoc->read(pxdoc, pxs, sizeof(int), dummy)) != sizeof(int)) {
				pxdoc->free(pxdoc, pxh->px_fields);
				pxdoc->free(pxdoc, pxh);
				return NULL;
			}
		}
	}

	/* read the tableName */
	ret = (int)pxdoc->read(pxdoc, pxs, tablenamelen, dummy);
	if(ret != tablenamelen) {
		pxdoc->free(pxdoc, pxh->px_fields);
		pxdoc->free(pxdoc, pxh);
		return NULL;
	}
	pxh->px_tablename = px_strdup(pxdoc, dummy);

	/* FIXME: The following will cut off field names longer than
	 * TMPBUFFSIZE-1 chars */
	pfield = pxh->px_fields;
	for(i=0; i<pxh->px_numfields; i++) {
		j=0;
		while((j < TMPBUFFSIZE-1) && ((ret = (int)pxdoc->read(pxdoc, pxs, 1, &c)) >= 0) && (c != '\0')) {
			dummy[j++] = c;
		}
		if(ret < 0) {
			pxdoc->free(pxdoc, pxh->px_tablename);
			pxdoc->free(pxdoc, pxh->px_fields);
			pxdoc->free(pxdoc, pxh);
			return NULL;
		}
		dummy[j] = '\0';
//		PX_get_data_alpha(pxdoc, dummy, strlen(dummy), &pfield->px_fname);
		pfield->px_fname = px_strdup(pxdoc, (const char *)dummy);
		pfield++;
	}

	return pxh;
}
/* }}} */
#undef TMPBUFFSIZE


/* get_datablock_head() {{{
 */
int get_datablock_head(pxdoc_t *pxdoc, pxstream_t *pxs, int datablocknr, TDataBlock *datablockhead)
{
	pxhead_t *pxh;
	int position, ret;

	pxh = pxdoc->px_head;
	position = pxh->px_headersize+(datablocknr-1)*pxh->px_maxtablesize*0x400;
	if((ret = pxdoc->seek(pxdoc, pxs, position, SEEK_SET)) < 0) {
		return -1;
	}

	if((ret = (int)pxdoc->read(pxdoc, pxs, sizeof(TDataBlock), datablockhead)) < 0) {
		return -1;
	}

	return 0;
}
/* }}} */








/* get_mb_head() {{{
 * get the header info from the file
 * basic header info & field descriptions
 */
mbhead_t *get_mb_head(pxblob_t *pxblob, pxstream_t *pxs) {
	pxdoc_t *pxdoc;
	TMbHeader mbhead;
	mbhead_t *mbh;
	int ret;

	pxdoc = pxblob->pxdoc;
	if(NULL == pxdoc) {
		return(NULL);
	}

	if((mbh = (mbhead_t *) pxdoc->malloc(pxdoc, sizeof(mbhead_t), _("Allocate memory for document header."))) == NULL) {
		px_error(pxdoc, PX_RuntimeError, _("Could not allocate memory for document header."));
		return NULL;
	}
	if(pxblob->seek(pxblob, pxs, 0, SEEK_SET) < 0) {
		px_error(pxdoc, PX_RuntimeError, _("Could not go to start of blob file."));
		return NULL;
	}
	if((ret = (int)pxblob->read(pxblob, pxs, sizeof(TMbHeader), &mbhead)) != sizeof(TMbHeader)) {
		px_error(pxdoc, PX_RuntimeError, _("Could not read header from paradox file."));
		pxdoc->free(pxdoc, mbh);
		return NULL;
	}

	mbh->modcount = get_short_le((const char *)&mbhead.modcount);
	return(mbh);
}
/* }}} */


/*
 * Local variables:
 * tab-width: 4
 * c-basic-offset: 4
 * End:
 * vim600: sw=4 ts=4 fdm=marker
 * vim<600: sw=4 ts=4
 */
