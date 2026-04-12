#include <stdio.h>
#include "px_intern.h"
#include "paradox.h"

void px_init_targetencoding(pxdoc_t *pxdoc) {
  pxdoc->out_iconvcd = (Riconv_t) -1;
}

void px_init_inputencoding(pxdoc_t *pxdoc) {
  pxdoc->in_iconvcd = (Riconv_t) -1;
}

int px_set_targetencoding(pxdoc_t *pxdoc) {
  if(pxdoc->targetencoding) {
    char buffer[30];
    snprintf(buffer, sizeof(buffer), "CP%d", pxdoc->px_head->px_doscodepage);
    
    if(pxdoc->out_iconvcd != (Riconv_t)(-1))
      Riconv_close(pxdoc->out_iconvcd);
    
    if((Riconv_t)(-1) == (pxdoc->out_iconvcd = Riconv_open(pxdoc->targetencoding, buffer))) {
      return -1;
    } else {
      return 0;
    }
  } else {
    return -1;
  }
  return 0;
}

int px_set_inputencoding(pxdoc_t *pxdoc) {
  if(pxdoc->inputencoding) {
    char buffer[30];
    snprintf(buffer, sizeof(buffer), "CP%d", pxdoc->px_head->px_doscodepage);
    
    if(pxdoc->in_iconvcd != (Riconv_t)(-1))
      Riconv_close(pxdoc->in_iconvcd);
    
    if((Riconv_t)(-1) == (pxdoc->in_iconvcd = Riconv_open(buffer, pxdoc->inputencoding))) {
      return -1;
    } else {
      return 0;
    }
  } else {
    return -1;
  }
  return 0;
}
