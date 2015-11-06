/*
**
** The C code is generated by ATS/Postiats
** The starting compilation time is: 2015-10-19: 21h:59m
**
*/

/*
** include runtime header files
*/
#ifndef _ATS_CCOMP_HEADER_NONE
#include "pats_ccomp_config.h"
#include "pats_ccomp_basics.h"
#include "pats_ccomp_typedefs.h"
#include "pats_ccomp_instrset.h"
#include "pats_ccomp_memalloc.h"
#ifndef _ATS_CCOMP_EXCEPTION_NONE
#include "pats_ccomp_memalloca.h"
#include "pats_ccomp_exception.h"
#endif // end of [_ATS_CCOMP_EXCEPTION_NONE]
#endif /* _ATS_CCOMP_HEADER_NONE */


/*
** include prelude cats files
*/
#ifndef _ATS_CCOMP_PRELUDE_NONE
//
#include "prelude/CATS/basics.cats"
#include "prelude/CATS/integer.cats"
#include "prelude/CATS/pointer.cats"
#include "prelude/CATS/bool.cats"
#include "prelude/CATS/char.cats"
#include "prelude/CATS/integer_ptr.cats"
#include "prelude/CATS/integer_fixed.cats"
#include "prelude/CATS/float.cats"
#include "prelude/CATS/memory.cats"
#include "prelude/CATS/string.cats"
#include "prelude/CATS/strptr.cats"
//
#include "prelude/CATS/filebas.cats"
//
#include "prelude/CATS/list.cats"
#include "prelude/CATS/option.cats"
#include "prelude/CATS/array.cats"
#include "prelude/CATS/arrayptr.cats"
#include "prelude/CATS/arrayref.cats"
#include "prelude/CATS/matrix.cats"
#include "prelude/CATS/matrixptr.cats"
//
#endif /* _ATS_CCOMP_PRELUDE_NONE */
/*
** for user-supplied prelude
*/
#ifdef _ATS_CCOMP_PRELUDE_USER
//
#include _ATS_CCOMP_PRELUDE_USER
//
#endif /* _ATS_CCOMP_PRELUDE_USER */
/*
** for user2-supplied prelude
*/
#ifdef _ATS_CCOMP_PRELUDE_USER2
//
#include _ATS_CCOMP_PRELUDE_USER2
//
#endif /* _ATS_CCOMP_PRELUDE_USER2 */

/*
staload-prologues(beg)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/pointer.dats: 1533(line=44, offs=1) -- 1572(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/integer.dats: 1636(line=51, offs=1) -- 1675(line=51, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/integer_ptr.dats: 1639(line=51, offs=1) -- 1678(line=51, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/integer_fixed.dats: 1641(line=51, offs=1) -- 1680(line=51, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/char.dats: 1610(line=48, offs=1) -- 1649(line=48, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/memory.dats: 1410(line=38, offs=1) -- 1449(line=39, offs=32)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/string.dats: 1609(line=48, offs=1) -- 1648(line=48, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/strptr.dats: 1609(line=48, offs=1) -- 1648(line=48, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/strptr.dats: 1671(line=52, offs=1) -- 1718(line=52, offs=48)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/integer.dats: 1636(line=51, offs=1) -- 1675(line=51, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/filebas.dats: 1613(line=48, offs=1) -- 1652(line=48, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/filebas.dats: 1675(line=52, offs=1) -- 1722(line=52, offs=48)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/integer.dats: 1636(line=51, offs=1) -- 1675(line=51, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/filebas.dats: 1745(line=56, offs=1) -- 1783(line=56, offs=39)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/stdio.sats: 1380(line=35, offs=1) -- 1418(line=37, offs=3)
*/

#include "libc/CATS/stdio.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/stdio.sats: 1898(line=62, offs=1) -- 1940(line=64, offs=27)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/sys/SATS/types.sats: 1390(line=36, offs=1) -- 1432(line=38, offs=3)
*/

#include "libc/sys/CATS/types.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/filebas.dats: 1861(line=61, offs=1) -- 1901(line=61, offs=41)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/sys/SATS/stat.sats: 1390(line=36, offs=1) -- 1431(line=38, offs=3)
*/

#include "libc/sys/CATS/stat.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/sys/SATS/stat.sats: 1712(line=52, offs=1) -- 1754(line=53, offs=35)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/sys/SATS/types.sats: 1390(line=36, offs=1) -- 1432(line=38, offs=3)
*/

#include "libc/sys/CATS/types.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/filebas.dats: 15323(line=844, offs=1) -- 15353(line=844, offs=31)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/stdio.sats: 1380(line=35, offs=1) -- 1418(line=37, offs=3)
*/

#include "libc/CATS/stdio.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/stdio.sats: 1898(line=62, offs=1) -- 1940(line=64, offs=27)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/sys/SATS/types.sats: 1390(line=36, offs=1) -- 1432(line=38, offs=3)
*/

#include "libc/sys/CATS/types.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/list.dats: 1527(line=44, offs=1) -- 1566(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/list.dats: 1567(line=45, offs=1) -- 1613(line=45, offs=47)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/unsafe.dats: 1532(line=44, offs=1) -- 1566(line=44, offs=35)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/list_vt.dats: 1536(line=44, offs=1) -- 1575(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/array.dats: 1534(line=44, offs=1) -- 1573(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/array.dats: 1574(line=45, offs=1) -- 1616(line=45, offs=43)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/arrayptr.dats: 1532(line=44, offs=1) -- 1571(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/arrayref.dats: 1532(line=44, offs=1) -- 1571(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/matrix.dats: 1535(line=44, offs=1) -- 1574(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/matrixptr.dats: 1538(line=44, offs=1) -- 1577(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/matrixref.dats: 1538(line=44, offs=1) -- 1577(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/stream.dats: 1523(line=44, offs=1) -- 1562(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/stream_vt.dats: 1523(line=44, offs=1) -- 1562(line=44, offs=40)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/tostring.dats: 1528(line=44, offs=1) -- 1567(line=45, offs=32)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/unsafe.dats: 1532(line=44, offs=1) -- 1566(line=44, offs=35)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/prelude/DATS/checkast.dats: 1531(line=44, offs=1) -- 1570(line=45, offs=32)
*/
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/malloc.sats: 1380(line=35, offs=1) -- 1419(line=37, offs=3)
*/

#include "libc/CATS/malloc.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/stdlib.sats: 1389(line=36, offs=1) -- 1428(line=38, offs=3)
*/

#include "libc/CATS/stdlib.cats"
/*
/usr/local/Cellar/ats2-postiats/0.2.0/lib/ats2-postiats-0.2.0/libc/SATS/stdlib.sats: 1760(line=54, offs=1) -- 1800(line=55, offs=33)
*/
/*
staload-prologues(end)
*/
/*
typedefs-for-tyrecs-and-tysums(beg)
*/
/*
typedefs-for-tyrecs-and-tysums(end)
*/
/*
dynconlst-declaration(beg)
*/
/*
dynconlst-declaration(end)
*/
/*
dyncstlst-declaration(beg)
*/
ATSdyncst_mac(atspre_g1int2uint_int_size)
ATSdyncst_mac(atslib_malloc_libc)
ATSdyncst_mac(atspre_assert_errmsg_bool1)
ATSdyncst_mac(atspre_gt_ptr1_intz)
ATSdyncst_mac(atslib_mfree_libc)
/*
dyncstlst-declaration(end)
*/
/*
dynvalist-implementation(beg)
*/
/*
dynvalist-implementation(end)
*/
/*
exnconlst-declaration(beg)
*/
#ifndef _ATS_CCOMP_EXCEPTION_NONE
ATSextern()
atsvoid_t0ype
the_atsexncon_initize
(
  atstype_exnconptr d2c, atstype_string exnmsg
) ;
#endif // end of [_ATS_CCOMP_EXCEPTION_NONE]
/*
exnconlst-declaration(end)
*/
/*
assumelst-declaration(beg)
*/
/*
assumelst-declaration(end)
*/
/*
extypelst-declaration(beg)
*/
/*
extypelst-declaration(end)
*/
ATSstatmpdec(statmp0, atstkind_t0ype(atstype_size)) ;
ATSstatmpdec(statmp1, atstkind_type(atstype_ptrk)) ;
// ATSstatmpdec_void(statmp2) ;
ATSstatmpdec(statmp3, atstkind_t0ype(atstype_bool)) ;
// ATSstatmpdec_void(statmp4) ;
#if(0)
ATSextern()
atsvoid_t0ype
mainats_void_0() ;
#endif // end of [QUALIFIED]

/*
/Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 722(line=23, offs=17) -- 729(line=23, offs=24)
*/
/*
local: 
global: mainats_void_0$1$0(level=0)
local: 
global: 
*/
ATSextern()
atsvoid_t0ype
mainats_void_0()
{
/* tmpvardeclst(beg) */
// ATStmpdec_void(tmpret5) ;
/* tmpvardeclst(end) */
ATSfunbody_beg()
/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 716(line=23, offs=11) -- 729(line=23, offs=24)
*/
ATSINSflab(__patsflab_main_void_0):
/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 727(line=23, offs=22) -- 729(line=23, offs=24)
*/
ATSINSmove_void(tmpret5, ATSPMVempty()) ;
ATSfunbody_end()
ATSreturn_void(tmpret5) ;
} /* end of [mainats_void_0] */

/*
** for initialization(dynloading)
*/
ATSdynloadflag_minit(_057_Users_057_sakurai_057_git_057_docs_057_gc_057_ats_basic_057_malloc_056_dats__dynloadflag) ;
ATSextern()
atsvoid_t0ype
_057_Users_057_sakurai_057_git_057_docs_057_gc_057_ats_basic_057_malloc_056_dats__dynload()
{
ATSfunbody_beg()
ATSdynload(/*void*/)
ATSdynloadflag_sta(
_057_Users_057_sakurai_057_git_057_docs_057_gc_057_ats_basic_057_malloc_056_dats__dynloadflag
) ;
ATSif(
ATSCKiseqz(
_057_Users_057_sakurai_057_git_057_docs_057_gc_057_ats_basic_057_malloc_056_dats__dynloadflag
)
) ATSthen() {
ATSdynloadset(_057_Users_057_sakurai_057_git_057_docs_057_gc_057_ats_basic_057_malloc_056_dats__dynloadflag) ;
/*
dynexnlst-initize(beg)
*/
/*
dynexnlst-initize(end)
*/
/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 239(line=8, offs=10) -- 704(line=21, offs=2)
*/
/*
letpush(beg)
*/
/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 250(line=9, offs=10) -- 262(line=9, offs=22)
*/
ATSINSmove(statmp0, atspre_g1int2uint_int_size(ATSPMVi0nt(1024))) ;

/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 282(line=10, offs=20) -- 296(line=10, offs=34)
*/
ATSINSmove(statmp1, atslib_malloc_libc(statmp0)) ;

/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 308(line=11, offs=11) -- 325(line=11, offs=28)
*/
ATSINSmove(statmp3, atspre_gt_ptr1_intz(statmp1, ATSPMVi0nt(0))) ;

/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 308(line=11, offs=11) -- 325(line=11, offs=28)
*/
ATSINSmove_void(statmp2, atspre_assert_errmsg_bool1(statmp3, ATSCSTSPmyloc("/Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 308(line=11, offs=11) -- 325(line=11, offs=28)"))) ;

/*
letpush(end)
*/

/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 518(line=16, offs=11) -- 545(line=16, offs=38)
*/
ATSINSmove_void(statmp4, atslib_mfree_libc(statmp1)) ;

/*
emit_instr: loc0 = /Users/sakurai/git/docs/gc/ats_basic/malloc.dats: 239(line=8, offs=10) -- 704(line=21, offs=2)
*/
/*
INSletpop()
*/
} /* ATSendif */
ATSfunbody_end()
ATSreturn_void(tmpret_void) ;
} /* end of [*_dynload] */

/*
** the ATS runtime
*/
#ifndef _ATS_CCOMP_RUNTIME_NONE
#include "pats_ccomp_runtime.c"
#include "pats_ccomp_runtime_memalloc.c"
#ifndef _ATS_CCOMP_EXCEPTION_NONE
#include "pats_ccomp_runtime2_dats.c"
#ifndef _ATS_CCOMP_RUNTIME_TRYWITH_NONE
#include "pats_ccomp_runtime_trywith.c"
#endif /* _ATS_CCOMP_RUNTIME_TRYWITH_NONE */
#endif // end of [_ATS_CCOMP_EXCEPTION_NONE]
#endif /* _ATS_CCOMP_RUNTIME_NONE */

/*
** the [main] implementation
*/
int
main
(
int argc, char **argv, char **envp
) {
int err = 0 ;
_057_Users_057_sakurai_057_git_057_docs_057_gc_057_ats_basic_057_malloc_056_dats__dynload() ;
ATSmainats_void_0(err) ;
return (err) ;
} /* end of [main] */

/* ****** ****** */

/* end-of-compilation-unit */
