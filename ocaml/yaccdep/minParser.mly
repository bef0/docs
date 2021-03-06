/***********************************************************************/
/*                                                                     */
/*                                OCaml                                */
/*                                                                     */
/*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         */
/*                                                                     */
/*  Copyright 1996 Institut National de Recherche en Informatique et   */
/*  en Automatique.  All rights reserved.  This file is distributed    */
/*  under the terms of the Q Public License version 1.0.               */
/*                                                                     */
/***********************************************************************/

/* The parser definition */

%{
open Location
open Asttypes
open Longident
open Parsetree
open Ast_helper

let mktyp d = Typ.mk ~loc:(symbol_rloc()) d
let mkpat d = Pat.mk ~loc:(symbol_rloc()) d
let mkexp d = Exp.mk ~loc:(symbol_rloc()) d
let mkmty d = Mty.mk ~loc:(symbol_rloc()) d
let mksig d = Sig.mk ~loc:(symbol_rloc()) d
let mkmod d = Mod.mk ~loc:(symbol_rloc()) d
let mkstr d = Str.mk ~loc:(symbol_rloc()) d
let mkclass d = Cl.mk ~loc:(symbol_rloc()) d
let mkcty d = Cty.mk ~loc:(symbol_rloc()) d
let mkctf d = Ctf.mk ~loc:(symbol_rloc()) d
let mkcf d = Cf.mk ~loc:(symbol_rloc()) d

let mkrhs rhs pos = mkloc rhs (rhs_loc pos)
let mkoption d =
  let loc = {d.ptyp_loc with loc_ghost = true} in
  Typ.mk ~loc (Ptyp_constr(mkloc (Ldot (Lident "*predef*", "option")) loc,[d]))

let reloc_pat x = { x with ppat_loc = symbol_rloc () };;
let reloc_exp x = { x with pexp_loc = symbol_rloc () };;

let mkoperator name pos =
  let loc = rhs_loc pos in
  Exp.mk ~loc (Pexp_ident(mkloc (Lident name) loc))

let mkpatvar name pos =
  Pat.mk ~loc:(rhs_loc pos) (Ppat_var (mkrhs name pos))

(*
  Ghost expressions and patterns:
  expressions and patterns that do not appear explicitly in the
  source file they have the loc_ghost flag set to true.
  Then the profiler will not try to instrument them and the
  -annot option will not try to display their type.

  Every grammar rule that generates an element with a location must
  make at most one non-ghost element, the topmost one.

  How to tell whether your location must be ghost:
  A location corresponds to a range of characters in the source file.
  If the location contains a piece of code that is syntactically
  valid (according to the documentation), and corresponds to the
  AST node, then the location must be real; in all other cases,
  it must be ghost.
*)
let ghexp d = Exp.mk ~loc:(symbol_gloc ()) d
let ghpat d = Pat.mk ~loc:(symbol_gloc ()) d
let ghtyp d = Typ.mk ~loc:(symbol_gloc ()) d
let ghloc d = { txt = d; loc = symbol_gloc () }
let ghstr d = Str.mk ~loc:(symbol_gloc()) d

let ghunit () =
  ghexp (Pexp_construct (mknoloc (Lident "()"), None))

let mkinfix arg1 name arg2 =
  mkexp(Pexp_apply(mkoperator name 2, ["", arg1; "", arg2]))

let neg_float_string f =
  if String.length f > 0 && f.[0] = '-'
  then String.sub f 1 (String.length f - 1)
  else "-" ^ f

let mkuminus name arg =
  match name, arg.pexp_desc with
  | "-", Pexp_constant(Const_int n) ->
      mkexp(Pexp_constant(Const_int(-n)))
  | "-", Pexp_constant(Const_int32 n) ->
      mkexp(Pexp_constant(Const_int32(Int32.neg n)))
  | "-", Pexp_constant(Const_int64 n) ->
      mkexp(Pexp_constant(Const_int64(Int64.neg n)))
  | "-", Pexp_constant(Const_nativeint n) ->
      mkexp(Pexp_constant(Const_nativeint(Nativeint.neg n)))
  | ("-" | "-."), Pexp_constant(Const_float f) ->
      mkexp(Pexp_constant(Const_float(neg_float_string f)))
  | _ ->
      mkexp(Pexp_apply(mkoperator ("~" ^ name) 1, ["", arg]))

let mkuplus name arg =
  let desc = arg.pexp_desc in
  match name, desc with
  | "+", Pexp_constant(Const_int _)
  | "+", Pexp_constant(Const_int32 _)
  | "+", Pexp_constant(Const_int64 _)
  | "+", Pexp_constant(Const_nativeint _)
  | ("+" | "+."), Pexp_constant(Const_float _) -> mkexp desc
  | _ ->
      mkexp(Pexp_apply(mkoperator ("~" ^ name) 1, ["", arg]))

let mkexp_cons consloc args loc =
  Exp.mk ~loc (Pexp_construct(mkloc (Lident "::") consloc, Some args))

let mkpat_cons consloc args loc =
  Pat.mk ~loc (Ppat_construct(mkloc (Lident "::") consloc, Some args))

let rec mktailexp nilloc = function
  | [] ->
      let loc = { nilloc with loc_ghost = true } in
      let nil = { txt = Lident "[]"; loc = loc } in
      Exp.mk ~loc (Pexp_construct (nil, None))
  | e1 :: el ->
      let exp_el = mktailexp nilloc el in
      let loc = {loc_start = e1.pexp_loc.loc_start;
               loc_end = exp_el.pexp_loc.loc_end;
               loc_ghost = true}
      in
      let arg = Exp.mk ~loc (Pexp_tuple [e1; exp_el]) in
      mkexp_cons {loc with loc_ghost = true} arg loc

let rec mktailpat nilloc = function
  | [] ->
      let loc = { nilloc with loc_ghost = true } in
      let nil = { txt = Lident "[]"; loc = loc } in
      Pat.mk ~loc (Ppat_construct (nil, None))
  | p1 :: pl ->
      let pat_pl = mktailpat nilloc pl in
      let loc = {loc_start = p1.ppat_loc.loc_start;
               loc_end = pat_pl.ppat_loc.loc_end;
               loc_ghost = true}
      in
      let arg = Pat.mk ~loc (Ppat_tuple [p1; pat_pl]) in
      mkpat_cons {loc with loc_ghost = true} arg loc

let mkstrexp e attrs =
  {
    pstr_desc = Pstr_eval (e, attrs);
    pstr_loc = e.pexp_loc
  }

let mkexp_constraint e (t1, t2) =
  match t1, t2 with
  | Some t, None -> ghexp(Pexp_constraint(e, t))
  | _, Some t -> ghexp(Pexp_coerce(e, t1, t))
  | None, None -> assert false

let array_function str name =

  ghloc (Ldot(Lident str, (if !Clflags.fast then "unsafe_" ^ name else name)))

let syntax_error () =

  raise Syntaxerr.Escape_error

let unclosed opening_name opening_num closing_name closing_num =
  raise(Syntaxerr.Error(Syntaxerr.Unclosed(rhs_loc opening_num, opening_name,
                                           rhs_loc closing_num, closing_name)))

let expecting pos nonterm =

    raise Syntaxerr.(Error(Expecting(rhs_loc pos, nonterm)))

let not_expecting pos nonterm =
    raise Syntaxerr.(Error(Not_expecting(rhs_loc pos, nonterm)))

let bigarray_function str name =
  ghloc (Ldot(Ldot(Lident "Bigarray", str), name))

let bigarray_untuplify = function
  | { pexp_desc = Pexp_tuple explist; pexp_loc = _ } -> explist
  | exp -> [exp]

let bigarray_get arr arg =
  let get = if !Clflags.fast then "unsafe_get" else "get" in
  match bigarray_untuplify arg with
  | [c1] ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Array1" get)),
                       ["", arr; "", c1]))
  | [c1;c2] ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Array2" get)),
                       ["", arr; "", c1; "", c2]))
  | [c1;c2;c3] ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Array3" get)),
                       ["", arr; "", c1; "", c2; "", c3]))
  | coords ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Genarray" "get")),
                       ["", arr; "", ghexp(Pexp_array coords)]))

let bigarray_set arr arg newval =
  let set = if !Clflags.fast then "unsafe_set" else "set" in
  match bigarray_untuplify arg with
  | [c1] ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Array1" set)),
                       ["", arr; "", c1; "", newval]))
  | [c1;c2] ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Array2" set)),
                       ["", arr; "", c1; "", c2; "", newval]))
  | [c1;c2;c3] ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Array3" set)),
                       ["", arr; "", c1; "", c2; "", c3; "", newval]))
  | coords ->
      mkexp(Pexp_apply(ghexp(Pexp_ident(bigarray_function "Genarray" "set")),
                       ["", arr;
                        "", ghexp(Pexp_array coords);
                        "", newval]))

let lapply p1 p2 =
  if !Clflags.applicative_functors
  then Lapply(p1, p2)
  else raise (Syntaxerr.Error(Syntaxerr.Applicative_path (symbol_rloc())))

let exp_of_label lbl pos =

  mkexp (Pexp_ident(mkrhs (Lident(Longident.last lbl)) pos))

let pat_of_label lbl pos =

  mkpat (Ppat_var (mkrhs (Longident.last lbl) pos))

let check_variable vl loc v =
  if List.mem v vl then
    raise Syntaxerr.(Error(Variable_in_scope(loc,v)))

let varify_constructors var_names t =
  let rec loop t =
    let desc =
      match t.ptyp_desc with
      | Ptyp_any -> Ptyp_any
      | Ptyp_var x ->
          check_variable var_names t.ptyp_loc x;
          Ptyp_var x
      | Ptyp_arrow (label,core_type,core_type') ->
          Ptyp_arrow(label, loop core_type, loop core_type')
      | Ptyp_tuple lst -> Ptyp_tuple (List.map loop lst)
      | Ptyp_constr( { txt = Lident s }, []) when List.mem s var_names ->
          Ptyp_var s
      | Ptyp_constr(longident, lst) ->
          Ptyp_constr(longident, List.map loop lst)
      | Ptyp_object (lst, o) ->
          Ptyp_object
            (List.map (fun (s, attrs, t) -> (s, attrs, loop t)) lst, o)
      | Ptyp_class (longident, lst) ->
          Ptyp_class (longident, List.map loop lst)
      | Ptyp_alias(core_type, string) ->
          check_variable var_names t.ptyp_loc string;
          Ptyp_alias(loop core_type, string)
      | Ptyp_variant(row_field_list, flag, lbl_lst_option) ->
          Ptyp_variant(List.map loop_row_field row_field_list,
                       flag, lbl_lst_option)
      | Ptyp_poly(string_lst, core_type) ->
          List.iter (check_variable var_names t.ptyp_loc) string_lst;
          Ptyp_poly(string_lst, loop core_type)
      | Ptyp_package(longident,lst) ->
          Ptyp_package(longident,List.map (fun (n,typ) -> (n,loop typ) ) lst)
      | Ptyp_extension (s, arg) ->
          Ptyp_extension (s, arg)
    in
    {t with ptyp_desc = desc}
  and loop_row_field  =
    function
      | Rtag(label,attrs,flag,lst) ->
          Rtag(label,attrs,flag,List.map loop lst)
      | Rinherit t ->
          Rinherit (loop t)
  in
  loop t

let wrap_type_annotation newtypes core_type body =
  let exp = mkexp(Pexp_constraint(body,core_type)) in
  let exp =
    List.fold_right (fun newtype exp -> mkexp (Pexp_newtype (newtype, exp)))
      newtypes exp
  in
  (exp, ghtyp(Ptyp_poly(newtypes,varify_constructors newtypes core_type)))

let wrap_exp_attrs body (ext, attrs) =
  (* todo: keep exact location for the entire attribute *)
  let body = {body with pexp_attributes = attrs @ body.pexp_attributes} in
  match ext with
  | None -> body
  | Some id -> ghexp(Pexp_extension (id, PStr [mkstrexp body []]))

let mkexp_attrs d attrs =
  wrap_exp_attrs (mkexp d) attrs

let mkcf_attrs d attrs =
  Cf.mk ~loc:(symbol_rloc()) ~attrs d

let mkctf_attrs d attrs =
  Ctf.mk ~loc:(symbol_rloc()) ~attrs d

%}

/* Tokens */

%token AMPERAMPER
%token AMPERSAND
%token AND
%token AS
%token ASSERT
%token BACKQUOTE
%token BANG
%token BAR
%token BARBAR
%token BARRBRACKET
%token BEGIN
%token <char> CHAR
%token CLASS
%token COLON
%token COLONCOLON
%token COLONEQUAL
%token COLONGREATER
%token COMMA
%token CONSTRAINT
%token DO
%token DONE
%token DOT
%token DOTDOT
%token DOWNTO
%token ELSE
%token END
%token EOF
%token EQUAL
%token EXCEPTION
%token EXTERNAL
%token FALSE
%token <string> FLOAT
%token FOR
%token FUN
%token FUNCTION
%token FUNCTOR
%token GREATER
%token GREATERRBRACE
%token GREATERRBRACKET
%token IF
%token IN
%token INCLUDE
%token <string> INFIXOP0
%token <string> INFIXOP1
%token <string> INFIXOP2
%token <string> INFIXOP3
%token <string> INFIXOP4
%token INHERIT
%token INITIALIZER
%token <int> INT
%token <int32> INT32
%token <int64> INT64
%token <string> LABEL
%token LAZY
%token LBRACE
%token LBRACELESS
%token LBRACKET
%token LBRACKETBAR
%token LBRACKETLESS
%token LBRACKETGREATER
%token LBRACKETPERCENT
%token LBRACKETPERCENTPERCENT
%token LESS
%token LESSMINUS
%token LET
%token <string> LIDENT
%token LPAREN
%token LBRACKETAT
%token LBRACKETATAT
%token LBRACKETATATAT
%token MATCH
%token METHOD
%token MINUS
%token MINUSDOT
%token MINUSGREATER
%token MODULE
%token MUTABLE
%token <nativeint> NATIVEINT
%token NEW
%token OBJECT
%token OF
%token OPEN
%token <string> OPTLABEL
%token OR
/* %token PARSER */
%token PERCENT
%token PLUS
%token PLUSDOT
%token PLUSEQ
%token <string> PREFIXOP
%token PRIVATE
%token QUESTION
%token QUOTE
%token RBRACE
%token RBRACKET
%token REC
%token RPAREN
%token SEMI
%token SEMISEMI
%token SHARP
%token SIG
%token STAR
%token <string * string option> STRING
%token STRUCT
%token THEN
%token TILDE
%token TO
%token TRUE
%token TRY
%token TYPE
%token <string> UIDENT
%token UNDERSCORE
%token VAL
%token VIRTUAL
%token WHEN
%token WHILE
%token WITH
%token <string * Location.t> COMMENT

%token EOL

/* Precedences and associativities.

Tokens and rules have precedences.  A reduce/reduce conflict is resolved
in favor of the first rule (in source file order).  A shift/reduce conflict
is resolved by comparing the precedence and associativity of the token to
be shifted with those of the rule to be reduced.

By default, a rule has the precedence of its rightmost terminal (if any).

When there is a shift/reduce conflict between a rule and a token that
have the same precedence, it is resolved using the associativity:
if the token is left-associative, the parser will reduce; if
right-associative, the parser will shift; if non-associative,
the parser will declare a syntax error.

We will only use associativities with operators of the kind  x * x -> x
for example, in the rules of the form    expr: expr BINOP expr
in all other cases, we define two precedences if needed to resolve
conflicts.

The precedences must be listed from low to high.
*/

%nonassoc IN
%nonassoc below_SEMI
%nonassoc SEMI                          /* below EQUAL ({lbl=...; lbl=...}) */
%nonassoc LET                           /* above SEMI ( ...; let ... in ...) */
%nonassoc below_WITH
%nonassoc FUNCTION WITH                 /* below BAR  (match ... with ...) */
%nonassoc AND             /* above WITH (module rec A: SIG with ... and ...) */
%nonassoc THEN                          /* below ELSE (if ... then ...) */
%nonassoc ELSE                          /* (if ... then ... else ...) */
%nonassoc LESSMINUS                     /* below COLONEQUAL (lbl <- x := e) */
%right    COLONEQUAL                    /* expr (e := e := e) */
%nonassoc AS
%left     BAR                           /* pattern (p|p|p) */
%nonassoc below_COMMA
%left     COMMA                         /* expr/expr_comma_list (e,e,e) */
%right    MINUSGREATER                  /* core_type2 (t -> t -> t) */
%right    OR BARBAR                     /* expr (e || e || e) */
%right    AMPERSAND AMPERAMPER          /* expr (e && e && e) */
%nonassoc below_EQUAL
%left     INFIXOP0 EQUAL LESS GREATER   /* expr (e OP e OP e) */
%right    INFIXOP1                      /* expr (e OP e OP e) */
%nonassoc below_LBRACKETAT
%nonassoc LBRACKETAT
%nonassoc LBRACKETATAT
%right    COLONCOLON                    /* expr (e :: e :: e) */
%left     INFIXOP2 PLUS PLUSDOT MINUS MINUSDOT PLUSEQ /* expr (e OP e OP e) */
%left     PERCENT INFIXOP3 STAR                 /* expr (e OP e OP e) */
%right    INFIXOP4                      /* expr (e OP e OP e) */
%nonassoc prec_unary_minus prec_unary_plus /* unary - */
%nonassoc prec_constant_constructor     /* cf. simple_expr (C versus C x) */
%nonassoc prec_constr_appl              /* above AS BAR COLONCOLON COMMA */
%nonassoc below_SHARP
%nonassoc SHARP                         /* simple_expr/toplevel_directive */
%nonassoc below_DOT
%nonassoc DOT
/* Finally, the first tokens of simple_expr are above everything else. */
%nonassoc BACKQUOTE BANG BEGIN CHAR FALSE FLOAT INT INT32 INT64
          LBRACE LBRACELESS LBRACKET LBRACKETBAR LIDENT LPAREN
          NEW NATIVEINT PREFIXOP STRING TRUE UIDENT
          LBRACKETPERCENT LBRACKETPERCENTPERCENT


/* Entry points */

%start implementation                   /* for implementation files */
%type <Parsetree.structure> implementation
%start interface                        /* for interface files */
%type <Parsetree.signature> interface
%start toplevel_phrase                  /* for interactive use */
%type <Parsetree.toplevel_phrase> toplevel_phrase
%start use_file                         /* for the #use directive */
%type <Parsetree.toplevel_phrase list> use_file
%start parse_core_type
%type <Parsetree.core_type> parse_core_type
%start parse_expression
%type <Parsetree.expression> parse_expression
%start parse_pattern
%type <Parsetree.pattern> parse_pattern
%%

/* Entry points */

implementation:
  | structure EOF                        { $1 }
  ;
interface:
  | signature EOF                        { $1 }
  ;
toplevel_phrase:
  | top_structure SEMISEMI               { Ptop_def $1 }
  | EOF                                  { raise End_of_file }
  ;
top_structure:
  | seq_expr                      { [mkstrexp $1 []] }
  | top_structure_tail            { $1 }
  ;
top_structure_tail:
  |                                      { [] }
  | structure_item top_structure_tail    { $1 :: $2 }
  ;
use_file:
  | use_file_tail                        { $1 }
  | seq_expr use_file_tail
                                         { Ptop_def[mkstrexp $1 []] :: $2 }
  ;
use_file_tail:
  | EOF                                       { [] }
  | SEMISEMI EOF                              { [] }
  | SEMISEMI seq_expr use_file_tail
                                              { Ptop_def[mkstrexp $2 []] :: $3 }
  | SEMISEMI structure_item use_file_tail     { Ptop_def[$2] :: $3 }
  | structure_item use_file_tail              { Ptop_def[$1] :: $2 }
  ;
parse_core_type:
  | core_type EOF { $1 }
  ;
parse_expression:
  | seq_expr EOF { $1 }
  ;
parse_pattern:
  | pattern EOF { $1 }
  ;

/* Module expressions */

functor_arg:
  | LPAREN RPAREN
      { mkrhs "*" 2, None }
  ;

functor_args:
  | functor_args functor_arg
      { $2 :: $1 }
  | functor_arg
      { [ $1 ] }
  ;

structure:
  | seq_expr structure_tail { mkstrexp $1 [] :: $2 }
  | structure_tail { $1 }
  ;
structure_tail:
  |                      { [] }
  | SEMISEMI structure   { $2 }
  | structure_item structure_tail { $1 :: $2 }
  ;
structure_item:
  | LET rec_flag let_bindings
      {
        match $3 with
        | [ {pvb_pat = { ppat_desc = Ppat_any; ppat_loc = _ };
             pvb_expr = exp; pvb_attributes = attrs}] ->
            let exp = wrap_exp_attrs exp (None,[]) in
            mkstr(Pstr_eval (exp, attrs))
        | l ->
            mkstr(Pstr_value($2, List.rev l))
      }
  | EXTERNAL val_ident COLON core_type EQUAL primitive_declaration
      { mkstr
          (Pstr_primitive (Val.mk (mkrhs $2 2) $4
                             ~prim:$6 ~attrs:[] ~loc:(symbol_rloc ()))) }
  | TYPE type_declarations
      { mkstr(Pstr_type (List.rev $2) ) }
  | MODULE TYPE ident
      { mkstr(Pstr_modtype (Mtd.mk (mkrhs $3 3)
                              ~attrs:[] ~loc:(symbol_rloc()))) }
  | open_statement { mkstr(Pstr_open $1) }
  ;

signature:
  |                      { [] }
  | SEMISEMI signature   { $2 }
  | signature_item signature { $1 :: $2 }
  ;
signature_item:
  | VAL val_ident COLON core_type
      { mksig(Psig_value
                (Val.mk (mkrhs $2 2) $4 ~attrs:[] ~loc:(symbol_rloc()))) }
  | EXTERNAL val_ident COLON core_type EQUAL primitive_declaration
      { mksig(Psig_value
                (Val.mk (mkrhs $2 2) $4 ~prim:$6
                   ~loc:(symbol_rloc()))) }
  | TYPE type_declarations
      { mksig(Psig_type (List.rev $2)) }
  | MODULE UIDENT EQUAL mod_longident
      { mksig(Psig_module (Md.mk (mkrhs $2 2)
                             (Mty.alias ~loc:(rhs_loc 4) (mkrhs $4 4))
                             ~attrs:[]
                             ~loc:(symbol_rloc())
                          )) }
  | MODULE TYPE ident
      { mksig(Psig_modtype (Mtd.mk (mkrhs $3 3)
                              ~attrs:[] ~loc:(symbol_rloc()))) }
  | open_statement
      { mksig(Psig_open $1) }
  ;
open_statement:
  | OPEN override_flag mod_longident
      { Opn.mk (mkrhs $3 3) ~override:$2 ~attrs:[] ~loc:(symbol_rloc()) }
  ;


constrain:
  | core_type EQUAL core_type          { $1, $3, symbol_rloc() }
  ;

/* Core expressions */

seq_expr:
  | expr        %prec below_SEMI  { $1 }
  | expr SEMI                     { reloc_exp $1 }
  | expr SEMI seq_expr            { mkexp(Pexp_sequence($1, $3)) }
  ;
expr:
  | simple_expr %prec below_SHARP
      { $1 }
  | simple_expr simple_labeled_expr_list
      { mkexp(Pexp_apply($1, List.rev $2)) }
  | LET rec_flag let_bindings_no_attrs IN seq_expr
      { mkexp_attrs (Pexp_let($2, List.rev $3, $5)) (None, []) }
  | LET OPEN override_flag mod_longident IN seq_expr
      { mkexp_attrs (Pexp_open($3, mkrhs $4 5, $6)) (None, []) }
  | FUNCTION opt_bar match_cases
      { mkexp_attrs (Pexp_function(List.rev $3)) (None, []) }
  | FUN LPAREN TYPE LIDENT RPAREN fun_def
      { mkexp_attrs (Pexp_newtype($4, $6)) (None, []) }
  | MATCH seq_expr WITH opt_bar match_cases
      { mkexp_attrs (Pexp_match($2, List.rev $5)) (None, []) }
  | TRY seq_expr WITH opt_bar match_cases
      { mkexp_attrs (Pexp_try($2, List.rev $5)) (None, []) }
  | expr_comma_list %prec below_COMMA
      { mkexp(Pexp_tuple(List.rev $1)) }
  | constr_longident simple_expr %prec below_SHARP
      { mkexp(Pexp_construct(mkrhs $1 1, Some $2)) }
  | name_tag simple_expr %prec below_SHARP
      { mkexp(Pexp_variant($1, Some $2)) }
  | IF seq_expr THEN expr ELSE expr
      { mkexp_attrs(Pexp_ifthenelse($2, $4, Some $6)) (None, []) }
  | IF seq_expr THEN expr
      { mkexp_attrs (Pexp_ifthenelse($2, $4, None)) (None, []) }
  | WHILE seq_expr DO seq_expr DONE
      { mkexp_attrs (Pexp_while($2, $4)) (None, []) }
  | FOR pattern EQUAL seq_expr direction_flag seq_expr DO
    seq_expr DONE
      { mkexp_attrs(Pexp_for($2, $4, $6, $5, $8)) (None, []) }
  | expr COLONCOLON expr
      { mkexp_cons (rhs_loc 2) (ghexp(Pexp_tuple[$1;$3])) (symbol_rloc()) }
  | LPAREN COLONCOLON RPAREN LPAREN expr COMMA expr RPAREN
      { mkexp_cons (rhs_loc 2) (ghexp(Pexp_tuple[$5;$7])) (symbol_rloc()) }
  | expr INFIXOP0 expr
      { mkinfix $1 $2 $3 }
  | expr INFIXOP1 expr
      { mkinfix $1 $2 $3 }
  | expr INFIXOP2 expr
      { mkinfix $1 $2 $3 }
  | expr INFIXOP3 expr
      { mkinfix $1 $2 $3 }
  | expr INFIXOP4 expr
      { mkinfix $1 $2 $3 }
  | expr PLUS expr
      { mkinfix $1 "+" $3 }
  | expr PLUSDOT expr
      { mkinfix $1 "+." $3 }
  | expr PLUSEQ expr
      { mkinfix $1 "+=" $3 }
  | expr MINUS expr
      { mkinfix $1 "-" $3 }
  | expr MINUSDOT expr
      { mkinfix $1 "-." $3 }
  | expr STAR expr
      { mkinfix $1 "*" $3 }
  | expr PERCENT expr
      { mkinfix $1 "%" $3 }
  | expr EQUAL expr
      { mkinfix $1 "=" $3 }
  | expr LESS expr
      { mkinfix $1 "<" $3 }
  | expr GREATER expr
      { mkinfix $1 ">" $3 }
  | expr OR expr
      { mkinfix $1 "or" $3 }
  | expr BARBAR expr
      { mkinfix $1 "||" $3 }
  | expr AMPERSAND expr
      { mkinfix $1 "&" $3 }
  | expr AMPERAMPER expr
      { mkinfix $1 "&&" $3 }
  | expr COLONEQUAL expr
      { mkinfix $1 ":=" $3 }
  | subtractive expr %prec prec_unary_minus
      { mkuminus $1 $2 }
  | additive expr %prec prec_unary_plus
      { mkuplus $1 $2 }
  | simple_expr DOT label_longident LESSMINUS expr
      { mkexp(Pexp_setfield($1, mkrhs $3 3, $5)) }
  | simple_expr DOT LPAREN seq_expr RPAREN LESSMINUS expr
      { mkexp(Pexp_apply(ghexp(Pexp_ident(array_function "Array" "set")),
                         ["",$1; "",$4; "",$7])) }
  | simple_expr DOT LBRACKET seq_expr RBRACKET LESSMINUS expr
      { mkexp(Pexp_apply(ghexp(Pexp_ident(array_function "String" "set")),
                         ["",$1; "",$4; "",$7])) }
  | simple_expr DOT LBRACE expr RBRACE LESSMINUS expr
      { bigarray_set $1 $4 $7 }
  | label LESSMINUS expr
      { mkexp(Pexp_setinstvar(mkrhs $1 1, $3)) }
  | ASSERT simple_expr %prec below_SHARP
      { mkexp_attrs (Pexp_assert $2) (None, []) }
  ;
simple_expr:
  | val_longident
      { mkexp(Pexp_ident (mkrhs $1 1)) }
  | constant
      { mkexp(Pexp_constant $1) }
  | constr_longident %prec prec_constant_constructor
      { mkexp(Pexp_construct(mkrhs $1 1, None)) }
  | name_tag %prec prec_constant_constructor
      { mkexp(Pexp_variant($1, None)) }
  | LPAREN seq_expr RPAREN
      { reloc_exp $2 }
  | BEGIN seq_expr END
      { wrap_exp_attrs (reloc_exp $2) (None, []) (* check location *) }
  | BEGIN END
      { mkexp_attrs (Pexp_construct (mkloc (Lident "()") (symbol_rloc ()),
                               None)) (None, []) }
  | LPAREN seq_expr type_constraint RPAREN
      { mkexp_constraint $2 $3 }
  | simple_expr DOT label_longident
      { mkexp(Pexp_field($1, mkrhs $3 3)) }
  | mod_longident DOT LPAREN seq_expr RPAREN
      { mkexp(Pexp_open(Fresh, mkrhs $1 1, $4)) }
  | simple_expr DOT LPAREN seq_expr RPAREN
      { mkexp(Pexp_apply(ghexp(Pexp_ident(array_function "Array" "get")),
                         ["",$1; "",$4])) }
  | simple_expr DOT LBRACKET seq_expr RBRACKET
      { mkexp(Pexp_apply(ghexp(Pexp_ident(array_function "String" "get")),
                         ["",$1; "",$4])) }
  | simple_expr DOT LBRACE expr RBRACE
      { bigarray_get $1 $4 }
  | LBRACE record_expr RBRACE
      { let (exten, fields) = $2 in mkexp (Pexp_record(fields, exten)) }
  | mod_longident DOT LBRACE record_expr RBRACE
      { let (exten, fields) = $4 in
        let rec_exp = mkexp(Pexp_record(fields, exten)) in
        mkexp(Pexp_open(Fresh, mkrhs $1 1, rec_exp)) }
  | LBRACKETBAR expr_semi_list opt_semi BARRBRACKET
      { mkexp (Pexp_array(List.rev $2)) }
  | LBRACKETBAR BARRBRACKET
      { mkexp (Pexp_array []) }
  | mod_longident DOT LBRACKETBAR expr_semi_list opt_semi BARRBRACKET
      { mkexp(Pexp_open(Fresh, mkrhs $1 1, mkexp(Pexp_array(List.rev $4)))) }
  | LBRACKET expr_semi_list opt_semi RBRACKET
      { reloc_exp (mktailexp (rhs_loc 4) (List.rev $2)) }
  | mod_longident DOT LBRACKET expr_semi_list opt_semi RBRACKET
      { let list_exp = reloc_exp (mktailexp (rhs_loc 6) (List.rev $4)) in
        mkexp(Pexp_open(Fresh, mkrhs $1 1, list_exp)) }
  | PREFIXOP simple_expr
      { mkexp(Pexp_apply(mkoperator $1 1, ["",$2])) }
  | BANG simple_expr
      { mkexp(Pexp_apply(mkoperator "!" 1, ["",$2])) }
  | LBRACELESS field_expr_list opt_semi GREATERRBRACE
      { mkexp (Pexp_override(List.rev $2)) }
  | LBRACELESS GREATERRBRACE
      { mkexp (Pexp_override [])}
  | mod_longident DOT LBRACELESS field_expr_list opt_semi GREATERRBRACE
      { mkexp(Pexp_open(Fresh, mkrhs $1 1, mkexp (Pexp_override(List.rev $4))))}
  | simple_expr SHARP label
      { mkexp(Pexp_send($1, $3)) }
  ;
simple_labeled_expr_list:
  | labeled_simple_expr
      { [$1] }
  | simple_labeled_expr_list labeled_simple_expr
      { $2 :: $1 }
  ;
labeled_simple_expr:
  | simple_expr %prec below_SHARP
      { ("", $1) }
  | label_expr
      { $1 }
  ;
label_expr:
  | LABEL simple_expr %prec below_SHARP
      { ($1, $2) }
  | TILDE label_ident
      { $2 }
  | QUESTION label_ident
      { ("?" ^ fst $2, snd $2) }
  | OPTLABEL simple_expr %prec below_SHARP
      { ("?" ^ $1, $2) }
  ;
label_ident:
  | LIDENT   { ($1, mkexp(Pexp_ident(mkrhs (Lident $1) 1))) }
  ;
let_bindings:
  | let_binding                                 { [$1] }
  | let_bindings AND let_binding                { $3 :: $1 }
  ;
let_bindings_no_attrs:
  | let_bindings {
      let l = $1 in
      List.iter
        (fun vb ->
          if vb.pvb_attributes <> [] then
            raise Syntaxerr.(Error(Not_expecting(vb.pvb_loc,"item attribute")))
        )
        l;
      l
    }
  ;
lident_list:
  | LIDENT                            { [$1] }
  | LIDENT lident_list                { $1 :: $2 }
  ;
let_binding:
  | let_binding_ {
      let (p, e) = $1 in Vb.mk ~loc:(symbol_rloc()) p e
    }
  ;
let_binding_:
  | val_ident fun_binding
      { (mkpatvar $1 1, $2) }
  | val_ident COLON typevar_list DOT core_type EQUAL seq_expr
      { (ghpat(Ppat_constraint(mkpatvar $1 1,
                               ghtyp(Ptyp_poly(List.rev $3,$5)))),
         $7) }
  | val_ident COLON TYPE lident_list DOT core_type EQUAL seq_expr
      { let exp, poly = wrap_type_annotation $4 $6 $8 in
        (ghpat(Ppat_constraint(mkpatvar $1 1, poly)), exp) }
  | pattern EQUAL seq_expr
      { ($1, $3) }
  ;
fun_binding:
  | strict_binding
      { $1 }
  | type_constraint EQUAL seq_expr
      { mkexp_constraint $3 $1 }
  ;
strict_binding:
  | EQUAL seq_expr
      { $2 }
  | LPAREN TYPE LIDENT RPAREN fun_binding
      { mkexp(Pexp_newtype($3, $5)) }
  ;
match_cases:
  | match_case { [$1] }
  | match_cases BAR match_case { $3 :: $1 }
  ;
match_case:
  | pattern MINUSGREATER seq_expr
      { Exp.case $1 $3 }
  | pattern WHEN seq_expr MINUSGREATER seq_expr
      { Exp.case $1 ~guard:$3 $5 }
  ;
fun_def:
  | MINUSGREATER seq_expr                       { $2 }
  | LPAREN TYPE LIDENT RPAREN fun_def
      { mkexp(Pexp_newtype($3, $5)) }
  ;
expr_comma_list:
  | expr_comma_list COMMA expr                  { $3 :: $1 }
  | expr COMMA expr                             { [$3; $1] }
  ;
record_expr:
  | simple_expr WITH lbl_expr_list              { (Some $1, $3) }
  | lbl_expr_list                               { (None, $1) }
  ;
lbl_expr_list:
  |  lbl_expr { [$1] }
  |  lbl_expr SEMI lbl_expr_list { $1 :: $3 }
  |  lbl_expr SEMI { [$1] }
  ;
lbl_expr:
  | label_longident EQUAL expr
      { (mkrhs $1 1,$3) }
  | label_longident
      { (mkrhs $1 1, exp_of_label $1 1) }
  ;
field_expr_list:
  | label EQUAL expr
      { [mkrhs $1 1,$3] }
  | field_expr_list SEMI label EQUAL expr
      { (mkrhs $3 3, $5) :: $1 }
  ;
expr_semi_list:
  | expr                                        { [$1] }
  | expr_semi_list SEMI expr                    { $3 :: $1 }
  ;
type_constraint:
  | COLON core_type                             { (Some $2, None) }
  | COLON core_type COLONGREATER core_type      { (Some $2, Some $4) }
  | COLONGREATER core_type                      { (None, Some $2) }
  ;

/* Patterns */

pattern:
  | simple_pattern
      { $1 }
  ;
simple_pattern:
  | val_ident %prec below_EQUAL
      { mkpat(Ppat_var (mkrhs $1 1)) }
  ;

/* Primitive declarations */

primitive_declaration:
  | STRING                                      { [fst $1] }
  | STRING primitive_declaration                { fst $1 :: $2 }
  ;

/* Type declarations */

type_declarations:
  | type_declaration                            { [$1] }
  | type_declarations AND type_declaration      { $3 :: $1 }
  ;

type_declaration:
  | optional_type_parameters LIDENT type_kind constraints
      { let (kind, priv, manifest) = $3 in
        Type.mk (mkrhs $2 2)
          ~params:$1 ~cstrs:(List.rev $4)
          ~kind ~priv ?manifest ~loc:(symbol_rloc())
       }
  ;
constraints:
  | constraints CONSTRAINT constrain        { $3 :: $1 }
  |                                         { [] }
  ;
type_kind:
  |          
      { (Ptype_abstract, Public, None) }
  | EQUAL core_type
      { (Ptype_abstract, Public, Some $2) }
  | EQUAL constructor_declarations
      { (Ptype_variant(List.rev $2), Public, None) }
  | EQUAL DOTDOT
      { (Ptype_open, Public, None) }
  | EQUAL core_type EQUAL DOTDOT
      { (Ptype_open, Public, Some $2) }
  ;
optional_type_parameters:
  |                                             { [] }
  | optional_type_parameter                     { [$1] }
  | LPAREN optional_type_parameter_list RPAREN  { List.rev $2 }
  ;
optional_type_parameter:
  | type_variance optional_type_variable        { $2, $1 }
  ;
optional_type_parameter_list:
  | optional_type_parameter                              { [$1] }
  | optional_type_parameter_list COMMA optional_type_parameter    { $3 :: $1 }
  ;
optional_type_variable:
  | QUOTE ident                                 { mktyp(Ptyp_var $2) }
  | UNDERSCORE                                  { mktyp(Ptyp_any) }
  ;


type_parameters:
  |                                             { [] }
  | type_parameter                              { [$1] }
  | LPAREN type_parameter_list RPAREN           { List.rev $2 }
  ;
type_parameter:
  | type_variance type_variable                   { $2, $1 }
  ;
type_variance:
  |                                             { Invariant }
  | PLUS                                        { Covariant }
  | MINUS                                       { Contravariant }
  ;
type_variable:
  | QUOTE ident                                 { mktyp(Ptyp_var $2) }
  ;
type_parameter_list:
  | type_parameter                              { [$1] }
  | type_parameter_list COMMA type_parameter    { $3 :: $1 }
  ;
constructor_declarations:
  | constructor_declaration                     { [$1] }
  | constructor_declarations BAR constructor_declaration { $3 :: $1 }
  ;
constructor_declaration:
  | constr_ident generalized_constructor_arguments
      {
       let args,res = $2 in
       Type.constructor (mkrhs $1 1) ~args ?res ~loc:(symbol_rloc()) ~attrs:[]
      }
  ;
generalized_constructor_arguments:
  |                                             { ([],None) }
  | OF core_type_list                           { (List.rev $2,None) }
  | COLON core_type_list MINUSGREATER simple_core_type
                                                { (List.rev $2,Some $4) }
  | COLON simple_core_type
                                                { ([],Some $2) }
  ;

/* "with" constraints (additional type equations over signature components) */

with_constraints:
  | with_constraint                             { [$1] }
  | with_constraints AND with_constraint        { $3 :: $1 }
  ;
with_constraint:
  | TYPE type_parameters label_longident with_type_binder core_type constraints
      { Pwith_type
          (mkrhs $3 3,
           (Type.mk (mkrhs (Longident.last $3) 3)
              ~params:$2
              ~cstrs:(List.rev $6)
              ~manifest:$5
              ~priv:$4
              ~loc:(symbol_rloc()))) }
  | TYPE type_parameters label COLONEQUAL core_type
      { Pwith_typesubst
          (Type.mk (mkrhs $3 3)
             ~params:$2
             ~manifest:$5
             ~loc:(symbol_rloc())) }
  | MODULE mod_longident EQUAL mod_ext_longident
      { Pwith_module (mkrhs $2 2, mkrhs $4 4) }
  | MODULE UIDENT COLONEQUAL mod_ext_longident
      { Pwith_modsubst (mkrhs $2 2, mkrhs $4 4) }
  ;
with_type_binder:
  | EQUAL          { Public }
  ;

/* Polymorphic types */

typevar_list:
  | QUOTE ident                             { [$2] }
  | typevar_list QUOTE ident                { $3 :: $1 }
  ;
poly_type:
  | core_type
      { $1 }
  | typevar_list DOT core_type
      { mktyp(Ptyp_poly(List.rev $1, $3)) }
  ;

/* Core types */

core_type:
  | core_type2
      { $1 }
  | core_type2 AS QUOTE ident
      { mktyp(Ptyp_alias($1, $4)) }
  ;
core_type2:
  | simple_core_type_or_tuple
      { $1 }
  | QUESTION LIDENT COLON core_type2 MINUSGREATER core_type2
      { mktyp(Ptyp_arrow("?" ^ $2 , mkoption $4, $6)) }
  | OPTLABEL core_type2 MINUSGREATER core_type2
      { mktyp(Ptyp_arrow("?" ^ $1 , mkoption $2, $4)) }
  | LIDENT COLON core_type2 MINUSGREATER core_type2
      { mktyp(Ptyp_arrow($1, $3, $5)) }
  | core_type2 MINUSGREATER core_type2
      { mktyp(Ptyp_arrow("", $1, $3)) }
  ;

simple_core_type:
  | simple_core_type2  %prec below_SHARP
      { $1 }
  | LPAREN core_type_comma_list RPAREN %prec below_SHARP
      { match $2 with [sty] -> sty | _ -> raise Parse_error }
  ;

simple_core_type2:
  | QUOTE ident
      { mktyp(Ptyp_var $2) }
  | UNDERSCORE
      { mktyp(Ptyp_any) }
  | type_longident
      { mktyp(Ptyp_constr(mkrhs $1 1, [])) }
  | simple_core_type2 type_longident
      { mktyp(Ptyp_constr(mkrhs $2 2, [$1])) }
  | LPAREN core_type_comma_list RPAREN type_longident
      { mktyp(Ptyp_constr(mkrhs $4 4, List.rev $2)) }
  | LESS meth_list GREATER
      { let (f, c) = $2 in mktyp(Ptyp_object (f, c)) }
  | LESS GREATER
      { mktyp(Ptyp_object ([], Closed)) }
  | LBRACKET tag_field RBRACKET
      { mktyp(Ptyp_variant([$2], Closed, None)) }
  | LBRACKET BAR row_field_list RBRACKET
      { mktyp(Ptyp_variant(List.rev $3, Closed, None)) }
  | LBRACKET row_field BAR row_field_list RBRACKET
      { mktyp(Ptyp_variant($2 :: List.rev $4, Closed, None)) }
  | LBRACKETGREATER opt_bar row_field_list RBRACKET
      { mktyp(Ptyp_variant(List.rev $3, Open, None)) }
  | LBRACKETGREATER RBRACKET
      { mktyp(Ptyp_variant([], Open, None)) }
  | LBRACKETLESS opt_bar row_field_list RBRACKET
      { mktyp(Ptyp_variant(List.rev $3, Closed, Some [])) }
  | LBRACKETLESS opt_bar row_field_list GREATER name_tag_list RBRACKET
      { mktyp(Ptyp_variant(List.rev $3, Closed, Some (List.rev $5))) }
  | LPAREN MODULE package_type RPAREN
      { mktyp(Ptyp_package $3) }
  ;
package_type:
  | mty_longident { (mkrhs $1 1, []) }
  | mty_longident WITH package_type_cstrs { (mkrhs $1 1, $3) }
  ;
package_type_cstr:
  | TYPE label_longident EQUAL core_type { (mkrhs $2 2, $4) }
  ;
package_type_cstrs:
  | package_type_cstr { [$1] }
  | package_type_cstr AND package_type_cstrs { $1::$3 }
  ;
row_field_list:
  | row_field                                   { [$1] }
  | row_field_list BAR row_field                { $3 :: $1 }
  ;
row_field:
  | tag_field                                   { $1 }
  | simple_core_type                            { Rinherit $1 }
  ;
tag_field:
  | name_tag OF opt_ampersand amper_type_list
      { Rtag ($1, [], $3, List.rev $4) }
  | name_tag
      { Rtag ($1, [], true, []) }
  ;
opt_ampersand:
  | AMPERSAND                                   { true }
  |                                             { false }
  ;
amper_type_list:
  | core_type                                   { [$1] }
  | amper_type_list AMPERSAND core_type         { $3 :: $1 }
  ;
name_tag_list:
  | name_tag                                    { [$1] }
  | name_tag_list name_tag                      { $2 :: $1 }
  ;
simple_core_type_or_tuple:
  | simple_core_type %prec below_LBRACKETAT     { $1 }
  | simple_core_type STAR core_type_list
      { mktyp(Ptyp_tuple($1 :: List.rev $3)) }
  ;

core_type_comma_list:
  | core_type                                   { [$1] }
  | core_type_comma_list COMMA core_type        { $3 :: $1 }
  ;
core_type_list:
  | simple_core_type %prec below_LBRACKETAT     { [$1] }
  | core_type_list STAR simple_core_type        { $3 :: $1 }
  ;
meth_list:
  | field SEMI meth_list                        { let (f, c) = $3 in ($1 :: f, c) }
  | field opt_semi                              { [$1], Closed }
  | DOTDOT                                      { [], Open }
  ;
field:
  | label COLON poly_type            { ($1, [], $3) }
  ;
label:
  | LIDENT                                      { $1 }
  ;

/* Constants */

constant:
  | INT                               { Const_int $1 }
  | CHAR                              { Const_char $1 }
  | STRING                            { let (s, d) = $1 in Const_string (s, d) }
  | FLOAT                             { Const_float $1 }
  | INT32                             { Const_int32 $1 }
  | INT64                             { Const_int64 $1 }
  | NATIVEINT                         { Const_nativeint $1 }
  ;

/* Identifiers and long identifiers */

ident:
  | UIDENT                                      { $1 }
  | LIDENT                                      { $1 }
  ;
val_ident:
  | LIDENT                                      { $1 }
  | LPAREN operator RPAREN                      { $2 }
  ;
operator:
  | PREFIXOP                                    { $1 }
  | INFIXOP0                                    { $1 }
  | INFIXOP1                                    { $1 }
  | INFIXOP2                                    { $1 }
  | INFIXOP3                                    { $1 }
  | INFIXOP4                                    { $1 }
  | BANG                                        { "!" }
  | PLUS                                        { "+" }
  | PLUSDOT                                     { "+." }
  | MINUS                                       { "-" }
  | MINUSDOT                                    { "-." }
  | STAR                                        { "*" }
  | EQUAL                                       { "=" }
  | LESS                                        { "<" }
  | GREATER                                     { ">" }
  | OR                                          { "or" }
  | BARBAR                                      { "||" }
  | AMPERSAND                                   { "&" }
  | AMPERAMPER                                  { "&&" }
  | COLONEQUAL                                  { ":=" }
  | PLUSEQ                                      { "+=" }
  | PERCENT                                     { "%" }
  ;
constr_ident:
  | UIDENT                                      { $1 }
  | LPAREN RPAREN                               { "()" }
  | COLONCOLON                                  { "::" }
  | FALSE                                       { "false" }
  | TRUE                                        { "true" }
  ;

val_longident:
  | val_ident                                   { Lident $1 }
  | mod_longident DOT val_ident                 { Ldot($1, $3) }
  ;
constr_longident:
  | mod_longident       %prec below_DOT         { $1 }
  | LBRACKET RBRACKET                           { Lident "[]" }
  | LPAREN RPAREN                               { Lident "()" }
  | FALSE                                       { Lident "false" }
  | TRUE                                        { Lident "true" }
  ;
label_longident:
  | LIDENT                                      { Lident $1 }
  | mod_longident DOT LIDENT                    { Ldot($1, $3) }
  ;
type_longident:
  | LIDENT                                      { Lident $1 }
  | mod_ext_longident DOT LIDENT                { Ldot($1, $3) }
  ;
mod_longident:
  | UIDENT                                      { Lident $1 }
  | mod_longident DOT UIDENT                    { Ldot($1, $3) }
  ;
mod_ext_longident:
  | UIDENT                                      { Lident $1 }
  | mod_ext_longident DOT UIDENT                { Ldot($1, $3) }
  | mod_ext_longident LPAREN mod_ext_longident RPAREN { lapply $1 $3 }
  ;
mty_longident:
  | ident                                       { Lident $1 }
  | mod_ext_longident DOT ident                 { Ldot($1, $3) }
  ;

/* Miscellaneous */

name_tag:
  | BACKQUOTE ident                             { $2 }
  ;
rec_flag:
  |                                             { Nonrecursive }
  | REC                                         { Recursive }
  ;
direction_flag:
  | TO                                          { Upto }
  | DOWNTO                                      { Downto }
  ;

override_flag:
  |                                             { Fresh }
  | BANG                                        { Override }
  ;
opt_bar:
  |                                             { () }
  | BAR                                         { () }
  ;
opt_semi:
  |                                             { () }
  | SEMI                                        { () }
  ;
subtractive:
  | MINUS                                       { "-" }
  | MINUSDOT                                    { "-." }
  ;
additive:
  | PLUS                                        { "+" }
  | PLUSDOT                                     { "+." }
  ;

%%
