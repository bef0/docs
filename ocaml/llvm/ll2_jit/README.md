# ll2_jit

[ll1_text](../ll1_text)のEmit部分のみを書き換えて、LLVMのライブラリを使いJITを行って実行します。

利点:

- コンパイルの処理はバックエンドと切り離して考える事ができます。
- バックエンドを複数持つ事が容易です。
- JITが出来る

欠点:

- エミットのパスがある
- ライブラリのリンクに時間がかかる

エミットのパスは残りますが、プロセス起動やパースの処理がなくなるので高速化できます。
JITも行えるので、コンパイルタイムに対象言語でプログラムを操作する事が容易です。
