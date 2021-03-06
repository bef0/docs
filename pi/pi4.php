<?php
class Senders {
  function __construct($a) {
    $this->a = $a;
  }

  function send($x) {
    // キューの後に値を付け加える
    $this->a[] = $x;
    return $this;
  }

  /**
   * 通信チャンネルyから値を受信し，関数fを適用する
   * @param Ref(Chan) $y
   * @param function $f
   */
  function recv($f) {
    if(count($this->a) == 0)
      return new Receivers(array($f));

    // 値がある
    // 一つだけ(x)を取り出す
    $x = array_shift($this->a);
    // 取り出した値を受信プロセスに渡す
    $f($x);
    return $this;
  }
}

class Receivers {
  function __construct($a) {
    $this->a = $a;
  }

  function send($x) {
    if (count($this->a) == 0)
      return new Senders(array($x));
    
    // 受信プロセスがある
    $f = array_shift($this->a); // １つ取り出す。
    $f($x);
    return $this;
  }

  /**
   * 通信チャンネルyから値を受信し，関数fを適用する
   * @param Ref(Chan) $y
   * @param function $f
   */
  function recv($f) {
    $this->a[] = $f;
    return $this;
  }
}

class Actor {
  function __construct() {
    $this->ref = new Senders(array());
  }
  /**
   * 通信チャンネルyに値xを送る
   * @param A x
   */
  function send($x) {
    $this->ref = $this->ref->send($x);
  }

  /**
   * 通信チャンネルyから値を受信し，関数fを適用する
   * @param function $f
   */
  function recv($f) {
    $this->ref = $this->ref->recv($f);
  }
}  
$x = new Actor();
$x->send(3);
$x->recv(function($y){ printf("%d\n", $y); });


class CActor extends Actor{
  function __construct() {
    parent::__construct();
    // 最初のrepeat()を生成
    $this->repeat();
  }

  // プロセスrepeat ()を再帰で定義
  function repeat() {
    // cから整数iを受信
    $this->recv(function($i) {
      // iを画面に表示
      printf("%d\n", $i);
      // またrepeat()自身を生成
      $this->repeat();
    });
  }

}

// 新しい通信チャンネルcを作る
$c = new CActor();

// cに1を送信
$c->send(1);

// cに2を送信
$c->send(2);

// 何度でも送信できる
$c->send(3);

class ServActor extends Actor {
  // サーバー・プロセスserv ()を再帰で定義
  function serv() {
    // servcから整数iと，返信のための
    // 通信チャンネルrepcの組を受け取る
    $this->recv(function($a) {
      // repcにiの2乗を返す
      $a["repc"]->send($a["i"] * $a["i"]);
      // serv自身を再び生成
      $this->serv();
    });
  }
  function __construct() {
    parent::__construct();
    // サーバー・プロセスを起動
    $this->serv();
  }
}
// サーバーがリクエストを受け付けるための
// 通信チャンネルservcを作る
$servc = new ServActor();


// 返信のためのチャンネルrを作る
$r = new Actor();

// サーバーに整数123とrを送る
$servc->send(array("i"=>123, "repc"=>$r));

// rから答えの整数jを受け取り表示
$r->recv(function($j){
  printf("%d\n", $j);
});
// サーバー・プロセスは何回でも
// 呼び出すことができる
$servc->send(array("i"=>45, "repc"=>$r));

$r->recv(function($j) {
  printf("%d\n", $j);
});

class FibActor extends Actor {

  // フィボナッチ・サーバーfib ()を定義
  function fib() {
    // fibcから引数nと，返値を送るための
    // 通信チャンネルrepcの組を受け取る
    $this->recv(function($a) {
      // またfib ()自身を生成しておく
      $this->fib();
      if($a["i"] <= 1) {
        // iが1以下ならiを返信
        $a["repc"]->send($a["i"]);
      } else {
        // フィボナッチ・サーバー自身を利用して
        // 引数がn-1とn-2の場合の返値を計算
        $repc1 = new Actor();
        $repc2 = new Actor();
        $this->send(array("i"=>$a["i"] - 1, "repc"=>$repc1));
        $this->send(array("i"=>$a["i"] - 2, "repc"=>$repc2));
        $repc1->recv(function($rep1)use(&$a,&$repc2) {
          $repc2->recv(function($rep2)use(&$a,$rep1) {
            // 二つの返値を足してrepcに返信
            $a["repc"]->send($rep1 + $rep2);
          });
        });
      }
    });
  }
  function __construct() {
    parent::__construct();
    // フィボナッチ・サーバーを起動
    $this->fib();
  }
}

// サーバーがリクエストを受け付けるための
// 通信チャンネルfibcを作る
$fibc = new FibActor();

// 返値を受け取るための通信チャンネルrを作る
$r = new Actor();
// 引数とrを送信
$fibc->send(array("i"=>10, "repc"=>$r));
// rから返値mを受け取って表示
$r->recv(function($m){
  printf("fib(10) = %d\n", $m);
});

