#include <stdio.h>
#include "px_intern.h"
#include "paradox.h"

/* px_init_targetencoding() {{{
 */
void px_init_targetencoding(pxdoc_t *pxdoc) {
  pxdoc->out_iconvcd = (iconv_t) -1;
}
/* }}} */

/* px_init_inputencoding() {{{
 */
void px_init_inputencoding(pxdoc_t *pxdoc) {
  pxdoc->in_iconvcd = (iconv_t) -1;
}
/* }}} */

/* px_set_targetencoding() {{{
 */
int px_set_targetencoding(pxdoc_t *pxdoc) {
  if(pxdoc->targetencoding) {
    char buffer[30];
    snprintf(buffer, sizeof(buffer), "CP%d", pxdoc->px_head->px_doscodepage);
    if(pxdoc->out_iconvcd != (iconv_t)(-1))
      iconv_close(pxdoc->out_iconvcd);
    if((iconv_t)(-1) == (pxdoc->out_iconvcd = iconv_open(pxdoc->targetencoding, buffer))) {
      return -1;
    } else {
      return 0;
    }
  } else {
    return -1;
  }
  return 0;
}
/* }}} */

/* px_set_inputencoding() {{{
 */
int px_set_inputencoding(pxdoc_t *pxdoc) {
  if(pxdoc->inputencoding) {
    char buffer[30];
    snprintf(buffer, sizeof(buffer), "CP%d", pxdoc->px_head->px_doscodepage);
    if(pxdoc->in_iconvcd != (iconv_t)(-1))
      iconv_close(pxdoc->in_iconvcd);
    if((iconv_t)(-1) == (pxdoc->in_iconvcd = iconv_open(buffer, pxdoc->inputencoding))) {
      return -1;
    } else {
      return 0;
    }
  } else {
    return -1;
  }
  return 0;
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
