let j2class src =
  let len = String.length src in
  if String.sub src (len - 2) 2 = ".j"
  then
    String.sub src 0 (len - 2) ^ ".class"
  else
    failwith ("filename is bad. " ^ src)

let lexbuf l =
	Parser.jas_file Lexer.token l

let file f =
(*
  Format.printf "***** original data@. %a@." JDataPP.pp_jclass a;
  let fp = open_in_bin (j2class f) in
  let a = JReader.parse_class (IO.input_channel fp) in
  close_in fp;

  List.iter (fun m ->
    try
      let codestr = JCode.get_code m in
      let code = JCodeReader.parse_code (a.consts) codestr in
      Format.printf "%a@." JCodePP.pp_jcode code;
    with
      | _ -> ()

  ) a.cmethods;

  Format.printf "***@.";
*)
  let inchan = open_in f in
  begin try
    Parser.sourcefile := Some f;
    let a = lexbuf (Lexing.from_channel inchan) in
    close_in inchan;
(*
    Format.printf "***** compiled data@. %a@." JDataPP.pp_jclass a;
*)
    let fp = open_out_bin (j2class f) in
    JWriter.encode_class (IO.output_channel fp) a;
    close_out fp;
(*
    List.iter (fun m ->
    try
      let codestr = JCode.get_code m in
      let code = JCodeReader.parse_code (a.consts) codestr in
      Format.printf "%a@." JCodePP.pp_jcode code;
    with
      | _ -> ()
    ) a.cmethods;
*)
    (*Javalib.unparse_class k (open_out (j2class f));*)
    (*JPrint.print_jasmin k stdout;*)
  with e ->
    close_in inchan;
    raise e
  end

let () =
  let usage = "jasc version 0.0.1\n  usage: jasc files" in
  let files = ref [] in
  Arg.parse [] (fun s -> files := !files @ [s]) usage;
  if !files = [] then print_endline usage else
  List.iter (fun f ->
    print_endline @@ "compile " ^ f;
    ignore (file f)
  ) !files
