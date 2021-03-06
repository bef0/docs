/*

multi vm gc

*/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <memory.h>

#define DEBUG
#define DEBUG2
void noprintf(char* str, ...){}
#ifdef DEBUG
#define debug printf
#else
#define debug noprintf
#endif
#ifdef DEBUG2
#define debug2 printf
#else
#define debug2 noprintf
#endif

typedef enum {
  OBJ_BOXED_ARRAY,
  OBJ_UNBOXED_ARRAY,
  OBJ_PAIR,
  OBJ_RECORD,
  OBJ_VM,
} ObjectType;

struct VM;

typedef struct ObjectHeader {
  struct ObjectHeader* next;
  unsigned int size;
  unsigned char type;
  unsigned char marked;
} ObjectHeader;

typedef union Object {
  struct {
    union Object *fst;
    union Object *snd;
  };
  union Object* field[0];

  char charv;
  short shortv;
  int intv;
  long longv;
  long long longlongv;
  char chars[0];
  short shorts[0];
  int ints[0];
  long longs[0];
  long long longlongs[0];

  unsigned char ucharv;
  unsigned short ushortv;
  unsigned int uintv;
  unsigned long ulongv;
  unsigned long long ulonglongv;
  unsigned char uchars[0];
  unsigned short ushorts[0];
  unsigned int uints[0];
  unsigned long ulongs[0];
  unsigned long long ulonglongs[0];
} Object;

typedef struct Frame {
  struct Frame* frame_prev;
  unsigned short frame_size;
  unsigned short frame_pos;
  Object* frame_data[0];
} Frame;

typedef struct VM {
  Object* record;
  ObjectHeader* heap_list;
  long heap_num;
  long heap_max;
} VM;

VM* vm;
Frame* frame_list;
Frame* frame_bottom;

int heap_find(VM* vm, ObjectHeader* o) {
  ObjectHeader* object = vm->heap_list;
  while (object) {
    if(object == o) return 1;
    object = object->next;
  }
  return 0;
}

long heap_count(ObjectHeader* object) {
  long sum = 0;
  while (object) {
    sum++;
    object = object->next;
  }
  return sum;
}

void gc_mark_object(Object* object) {
  ObjectHeader* head = &((ObjectHeader*)object)[-1];
  debug("mark %p\n",head);
  long size;
  if (!heap_find(vm, head)) {
    debug2("******** unfind in heap %p\n", &head[1]);
    return;
  }
  debug2("find\n");
  if (head->marked) return;
  long* bitmap;
  head->marked = 1;
  switch(head->type) {
    case OBJ_BOXED_ARRAY:
      debug("BOXED_ARRAY\n");
      size = ((int)head->size) / sizeof(long);
      debug2("size=%ld\n",size);
      for(int i = 0; i < size; i++) 
          gc_mark_object(object->field[i]);
      debug2("END\n");
      break;
    case OBJ_PAIR:
      debug("PAIR\n");
      gc_mark_object(object->fst);
      gc_mark_object(object->snd);
      break;
    case OBJ_UNBOXED_ARRAY:
      debug("UNBOXED ARRAY\n");
      break;
    case OBJ_VM:
      debug("VM\n");
      break;
    case OBJ_RECORD:
      size = ((int)head->size) / sizeof(long);
      debug("RECORD size=%ld\n", size);
      bitmap = &object->longs[size];
      debug2("size=%ld\n",size);
      for(int i = 0; i < size; i++) {
        if(bitmap[i/sizeof(long)] & (1 << (i % sizeof(long))))
          gc_mark_object(object->field[i]);
        else {
          debug2("skip %d\n", i);
        }
      }
      break;
  }
}

void gc_mark() {
  Frame* frame = frame_list;
  while(frame != frame_bottom) {
    debug2("gc mark %p size %ld\n", frame, frame->frame_size);
    int pos = frame->frame_size;
    if(pos > frame->frame_pos) pos = frame->frame_pos;
    for(int i = 0; i < pos; i++) {
      gc_mark_object(frame->frame_data[i]);
      debug2("done\n");
    }
    debug2("next %p\n", frame);
    debug2("next prev %p %p\n", frame->frame_prev, frame_bottom);
    frame = frame->frame_prev;
  }
  debug2("gc mark done\n");
}

void vm_finalize(VM* _vm);

void gc_sweep(VM* _vm) {
  ObjectHeader** object = &(vm->heap_list);
  debug2("object =%p\n", object);
  while (*object) {
    if (!(*object)->marked) {
      ObjectHeader* unreached = *object;
      *object = unreached->next;

      if(unreached->type == OBJ_VM) vm_finalize((VM*)&unreached[1]);
      
      free(unreached);

      vm->heap_num--;
    } else {
      (*object)->marked = 0;
      if(_vm) {
        printf("gc sweep vm\n");
        ObjectHeader* moving = *object;
        *object = moving->next;
        debug2("id change\n");
        _vm->heap_num++;
        moving->next = _vm->heap_list;
        _vm->heap_list = moving;
        printf("heap_num %ld %ld\n", _vm->heap_num, heap_count(_vm->heap_list));
        assert(_vm->heap_num == heap_count(_vm->heap_list));
      } else {
        object = &(*object)->next;
      }
    }
  }
}

void gc_collect() {
  long prev_num = vm->heap_num;

  debug2("gc mark\n");
  gc_mark();
  debug2("gc sweep\n");
  gc_sweep(NULL);

  vm->heap_max = prev_num * 2;

  debug("Collected %ld objects, %ld remaining.\n", prev_num - vm->heap_num,
         vm->heap_num);
}

Object* gc_collect_end_vm(Object* data, VM* _vm) {
  long prev_num = vm->heap_num;
  debug2("gc mark\n");
  gc_mark_object(data);
  debug2("gc sweep\n");
  gc_sweep(_vm);

  vm->heap_max = prev_num * 2;

  debug("Collected %ld objects, %ld moving.\n", prev_num - vm->heap_num,
         vm->heap_num);
  return data;
}

void gc_collect_pipe(Object* data) {
  long prev_num = vm->heap_num;
  gc_mark_object(data);
  gc_sweep(NULL);

  vm->heap_max = prev_num * 2;

  debug("Collected %ld objects, %ld remaining.\n", prev_num - vm->heap_num,
         vm->heap_num);
}

#define PUSH_VM(vmname) \
  VM* vmname = vm; \
  vm = vm_new(); \
  Frame* vmname##_tmp_bottom = frame_bottom; \

#define POP_VM(vmname,root) \
  printf("********* POP_VM %p -> %p\n", vm, vmname); \
  gc_collect_end_vm(root,vmname); \
  frame_bottom = vmname##_tmp_bottom; \
  printf("********* POP_VM DONE %ld -> %ld\n", vm->heap_num, vmname->heap_num); \
  vm = vmname; \

Object* gc_alloc(ObjectType type, int size) {
  debug2("gc alloc\n");
  debug2("vm=%p\n",vm);

  ObjectHeader* head = (ObjectHeader*)malloc(sizeof(ObjectHeader)+size);

  debug("gc_alloc %p\n", head);
  head->type = type;
  head->next = vm->heap_list;
  vm->heap_list = head;
  head->marked = 0;
  head->size=size;
  vm->heap_num++;

  return (Object*)&head[1];
}

#define gc_oarray0(size) (gc_alloc(OBJ_BOXED_ARRAY, sizeof(Object*)*size))

Object* gc_add_pool(Frame* frame_list, Object* head) {

  int frame_pos = frame_list->frame_pos;
  int frame_size = frame_list->frame_size-1;
  Object** frame_data = frame_list->frame_data;
  
  if (frame_pos < frame_size) {// フレームサイズ内ならそのまま使用する
    frame_data += frame_list->frame_pos;
  } else {// 足りなくなったら追加領域を使う
    frame_data += frame_size;
    frame_pos -= frame_size;
    // 追加時
    if (frame_pos == 0) {
      *frame_data = gc_oarray0(2);
    } else {
      int add_size = ((ObjectHeader*)*frame_data)[-1].size/sizeof(void*);
      if(add_size==frame_pos) {
        Object* frame_data2 = gc_oarray0(add_size*2);
        memcpy((void*)frame_data2, (void*)*frame_data, sizeof(Object*)*add_size);
        *frame_data = frame_data2;
      }
    }
    frame_data = (Object**)(*frame_data);
    frame_data += frame_pos;
  }
  *frame_data = head;
  frame_list->frame_pos++;
  if (vm->heap_num == vm->heap_max) gc_collect();
  return head;
}

#define gc_alloc_pair() (gc_alloc(OBJ_PAIR, sizeof(Object*)*2))
#define gc_alloc_boxed_array(size) (gc_alloc(OBJ_BOXED_ARRAY, sizeof(Object*)*size))
#define gc_alloc_unboxed_array(size) (gc_alloc(OBJ_UNBOXED_ARRAY, size))
#define gc_alloc_record(n) (gc_alloc(OBJ_RECORD, sizeof(Object*)*n+RECORD_BITMAP_NUM(n)))
#define RECORD_BITMAP_NUM(n) (((n)+sizeof(long)*8-1) / (sizeof(long)*8) )
#define BIT(n) (1 << n)

Object* gc_alloc_int(int n) {
  int* data = (int*)gc_alloc(OBJ_UNBOXED_ARRAY, sizeof(int)*1);

  debug("int ptr %p\n", data);
  *data = n;
  return (Object*)data;
}


Object* gc_copy(VM* vm, Object* object) {
  ObjectHeader* head = &((ObjectHeader*)object)[-1];
  debug("gc copy %p\n",head);
  long size;
  if (!heap_find(vm, head)) return object;
  long* bitmap;
  Object* obj;
  switch(head->type) {
    case OBJ_BOXED_ARRAY:
      obj = gc_alloc((ObjectType)head->type, head->size);
      size = ((int)head->size) / sizeof(long);
      debug("size=%ld\n",size);
      for(int i = 0; i < size; i++)
          obj->field[i] = gc_copy(vm,object->field[i]);
      break;
    case OBJ_PAIR:
      obj = gc_alloc((ObjectType)head->type, head->size);
      obj->fst = gc_copy(vm,object->fst);
      obj->snd = gc_copy(vm,object->snd);
      break;
    case OBJ_UNBOXED_ARRAY:
    case OBJ_VM:
      obj = gc_alloc((ObjectType)head->type, head->size);
      memcpy(obj, object, head->size);
      break;
    case OBJ_RECORD:
      size = ((int)head->size) / sizeof(long);
      obj = gc_alloc((ObjectType)head->type, head->size);
      memcpy(obj, object, head->size);
      bitmap = &object->longs[size];
      for(int i = 0; i < size; i++) {
        if(bitmap[i/sizeof(long)] & (1 << (i % sizeof(long))))
          obj->field[i] = gc_copy(vm,object->field[i]);
      }
      break;
  }
  return obj;
}

#define pool(a) (gc_add_pool(frame_list, a))
#define ENTER_FRAME(frame, SIZE) \
  Object* frame[SIZE+3]; \
  ((Frame*)frame)->frame_prev = frame_list; \
  ((Frame*)frame)->frame_size = SIZE+1; \
  ((Frame*)frame)->frame_pos = 0; \
  frame_list = (Frame*)frame; \

#define LEAVE_FRAME(frame) \
  frame_list = frame_list->frame_prev;

#define pool_ret(a) (gc_add_pool(frame_list->frame_prev, a))
Object* root_frame[256+3];

Object* vm_get_record(VM* _vm) {
  return gc_copy(_vm, _vm->record);
}

void vm_finalize(VM* _vm) {
  VM* tmp_vm = vm;

  vm = _vm;
  gc_collect();
  vm = tmp_vm;
}

void vm_end(Object* o, VM* vm) {
  gc_collect_end_vm(o, vm);
}

Object* vm_end_record(VM* vm) {
  gc_collect_end_vm(vm->record, vm);
  return vm->record;
}

VM* vm_new() {
  debug("vm_new\n");
  VM* vm = (VM*)gc_alloc(OBJ_VM, sizeof(VM));
  debug("gc alloc ok\n");
  vm->record = NULL;
  vm->heap_list = NULL;
  vm->heap_num = 0;
  vm->heap_max = 256;
  return vm;
}

void gc_init() {
  vm = (VM*)malloc(sizeof(VM));
  vm->record = NULL;
  vm->heap_list = NULL;
  vm->heap_num = 0;
  vm->heap_max = 8;
  ((Frame*)root_frame)->frame_prev = NULL;
  ((Frame*)root_frame)->frame_size = 256+1;
  ((Frame*)root_frame)->frame_pos = 0;
  frame_bottom = NULL;
}

void gc_free() {
  gc_collect();
  assert(vm->heap_num==0);
  free(vm);
}

void test() {
  void* frame[2+1];
  frame[0] = (void*)frame_list;
  frame[1] = (void*)2;
  frame_list = (Frame*)frame;
  Object* a = pool(gc_alloc(OBJ_BOXED_ARRAY,sizeof(long)*2));

  assert(vm->heap_num==1);
  gc_collect();
  assert(vm->heap_num==1);

  frame_list = frame_list->frame_prev;
}

void test2() {
  ENTER_FRAME(frame, 1);
  Object* a = pool(gc_alloc(OBJ_BOXED_ARRAY,sizeof(long)*2));
  assert(vm->heap_num==1);
  gc_collect();
  assert(vm->heap_num==1);
  LEAVE_FRAME(frame);
}


void test3() {
  ENTER_FRAME(frame,3);

  // ペア
  Object* A = pool(gc_alloc_pair());
  A->fst = gc_alloc_int(10);
  A->snd = gc_alloc_int(20);

  // オブジェクト配列
  Object* B = pool(gc_alloc_boxed_array(2));
  B->field[0] = gc_alloc_int(30);
  B->field[1] = gc_alloc_int(40);

  // int配列
  Object* unboxed = pool(gc_alloc_unboxed_array(sizeof(int)*2));
  unboxed->ints[0] = 50;
  unboxed->ints[1] = 60;

  printf("data1 = %p %d\n", A->fst, A->fst->intv);
  printf("data2 = %p %d\n", A->snd, A->snd->intv);

  printf("data3 = %p %d\n", B->field[0], B->field[0]->intv);
  printf("data4 = %p %d\n", B->field[1], B->field[1]->intv);

  printf("data5 = %p %d\n", &unboxed->ints[0], unboxed->ints[0]);
  printf("data6 = %p %d\n", &unboxed->ints[1], unboxed->ints[1]);
  assert(vm->heap_num==7);
  gc_collect();
  assert(vm->heap_num==7);
  LEAVE_FRAME(frame);
}

Object* test_int(int n) {
  ENTER_FRAME(frame,1);
  Object* A = pool_ret(pool(gc_alloc_int(n+10)));
  gc_collect();
  LEAVE_FRAME(frame);
  gc_collect();
  return A;
}

void test_record() {
  ENTER_FRAME(frame,2);

  // レコード
  enum {RECORD_SIZE=3,RECORD_BITMAP=BIT(1)|BIT(2)};
  Object* A = pool(gc_alloc_record(RECORD_SIZE));
  A->longs[RECORD_SIZE] = RECORD_BITMAP;// レコードのビットマップ(cpuビット数分でアラインする。ビットマップもcpu bit数)
  A->longs[0] = 10; // undata
  A->field[1] = gc_alloc_int(20);
  A->field[2] = test_int(30);

  assert(vm->heap_num==3);
  gc_collect();
  assert(vm->heap_num==3);
  LEAVE_FRAME(frame);
}

Object* test_new_vm2(Object* data) {
  ENTER_FRAME(frame,3);

  // レコード
  enum {RECORD_SIZE=3,RECORD_BITMAP=BIT(1)|BIT(2)};
  Object* A = pool(gc_alloc_record(RECORD_SIZE)); // 4
  A->longs[RECORD_SIZE] = RECORD_BITMAP;// レコードのビットマップ(cpuビット数分でアラインする。ビットマップもcpu bit数)
  A->longs[0] = 100; // undata
  A->field[1] = gc_alloc_int(200); // 5
  A->field[2] = data;

  Object* B = gc_alloc_int(3); // 6
  Object* C = gc_alloc_int(5); // 7

  LEAVE_FRAME(frame);
  return A;
}

/*
void test_new_vm() {
  enum {frame_START, frame_SIZE, A, B, frame_END};
  ENTER_FRAME_ENUM(frame);

  // レコード
  Object* A = pool(gc_alloc_int(1)); // 1

  assert(vm->heap_num==1);

  PUSH_VM(vm1);
    enum {frame1_START, frame1_SIZE, C, frame1_END};
    ENTER_FRAME_ENUM(frame1);

    assert(vm->heap_num==0);

    PUSH_VM(vm2);
      ENTER_FRAME(frame2,1);

      assert(vm->heap_num==0);
      Object* C = test_new_vm2(A);
      assert(vm->heap_num==4);

      LEAVE_FRAME(frame2);
    POP_VM(vm2, C);// 6と7が消える。
    assert(vm->heap_num==3);// ヒープには、cのデータと世界のデータが残る
    Object* B = C;
    LEAVE_FRAME(frame1);
  printf("id change check.........\n");
  POP_VM(vm1,frame[B]);// ヒープには世界のデータともとのデータに新しい2つのデータで4つ
  assert(vm->heap_num==4);
  printf("id change check.........\n");
  gc_collect();// 世界のデータが消えて3つに
  assert(vm->heap_num==3);
  LEAVE_FRAME(frame);
}*/
/*
void test_pipes1() {
  enum {frame_START, frame_SIZE, A, B, C, frame_END};
  ENTER_FRAME_ENUM(frame);

  A = gc_alloc_int(1); // 1
  assert(vm->heap_num==1);

  PUSH_VM(vm1);

    assert(vm->heap_num==0);
    frame[B] = test_new_vm2(A);
    assert(vm->heap_num==4);
    frame[B] = test_new_vm2(frame[B]);
    assert(vm->heap_num==8);
    frame[B] = test_new_vm2(frame[B]);
    assert(vm->heap_num==12);
  printf("id change check.........\n");
  POP_VM(vm1,frame[B]);
  assert(vm->heap_num==8);
  printf("id change check.........\n");
  gc_collect();
  assert(vm->heap_num==7);
  LEAVE_FRAME(frame);
}

void test_pipes2() {
  enum {frame_START, frame_SIZE, A, B, C, frame_END};
  ENTER_FRAME_ENUM(frame);

  A = gc_alloc_int(1); // 1

  assert(vm->heap_num==1);
  PUSH_VM(vm1);
    assert(vm->heap_num==0);
    frame[B] = test_new_vm2(A); // 生きているのが2つ死んでいるのが2つ
    assert(vm->heap_num==4);
    gc_collect_pipe(frame[B]);// bだけコピーして後は消す
    assert(vm->heap_num==2);
    frame[B] = test_new_vm2(frame[B]);// bを渡すと 2つのデータが入ってるのを渡す
    assert(vm->heap_num==6); // 生きてる４、死んでる2
    gc_collect_pipe(frame[B]);// bだけコピーして後は消す
    assert(vm->heap_num==4);// 生きてる4
    frame[B] = test_new_vm2(frame[B]);// 4+4=
    assert(vm->heap_num==8);// 4 + 4 = 8 生きてる6死んでる2と
    gc_collect_pipe(frame[B]);// bだけコピーして後は消す
    assert(vm->heap_num==6);// 生きてる6

  printf("id change check.........\n");
  POP_VM(vm1, frame[B]); // 世界が終わる
  // ヒープ上には、元のデータ1と世界のデータ1と6つの生きているで8個
  assert(vm->heap_num==8);
  printf("id change check.........\n");
  gc_collect();// gcで世界のデータが消える。
  assert(vm->heap_num==7);
  LEAVE_FRAME(frame);
}
*/
void test_multi_vm() {
  ENTER_FRAME(frame,8);
  Object* A = pool(gc_alloc_int(1));

  assert(vm->heap_num==1);
  VM* tmp_vm = pool(vm);
  VM* VM1 = pool(vm_new());// 世界を作る
  VM* VM2 = pool(vm_new());// 世界を作る
  assert(vm->heap_num==3);
  vm = VM1;// 世界を移動
    assert(vm->heap_num==0);
    vm->record = test_int(A->intv);// 計算する
    assert(vm->heap_num==1);

  Object* C;
  vm = VM2;// 世界を移動
    assert(vm->heap_num==0);
    C = pool(test_int(A->intv));// 計算する
    assert(vm->heap_num==1);
  vm_end(C, tmp_vm);
  
  vm = tmp_vm;// 元に戻る
  assert(vm->heap_num==4);

  Object* B = pool(vm_get_record(VM1));// コピーとる
  assert(vm->heap_num==5);
  printf("id change check.........\n");
  gc_collect();
  assert(vm->heap_num==5);
  LEAVE_FRAME(frame);
}

void test_multi() {
  ENTER_FRAME(frame,3);

  Object* A = pool(gc_alloc_int(1));
  Object* B;
  assert(vm->heap_num==1);
  PUSH_VM(vm1);// vmオブジェクトが作られる
    assert(vm->heap_num==0);
    assert(vm1->heap_num==2);
  POP_VM(vm1, B);
  assert(vm->heap_num==2);
  gc_collect();// 世界が消える
  assert(vm->heap_num==1);


  PUSH_VM(vm2);
    assert(vm2->heap_num==2); // 世界が増える
    assert(vm->heap_num==0);
    B = pool(test_int(A->intv));
    assert(vm->heap_num==1);
    assert(vm2->heap_num==2);
  POP_VM(vm2, B);
  assert(vm->heap_num==3);// frame2の世界と値が増えた

  gc_collect();// frame2世界が消えた
  assert(vm->heap_num==2);

  LEAVE_FRAME(frame);
}

int main() {

  printf("------------- test\n");
  gc_init();
  test();
  gc_free();

  printf("------------- test2\n");
  gc_init();
  test2();
  gc_free();

  printf("------------- test3\n");
  gc_init();
  test3();
  gc_free();

  printf("------------- test4\n");
  gc_init();
  test_record();
  gc_free();

/*
  printf("------------- test new vm\n");
  gc_init();
  test_new_vm();
  gc_free();
*/
  printf("------------- test multi vm\n");
  gc_init();
  test_multi_vm();
  gc_free();
/*
  printf("------------- test pipes1\n");
  gc_init();
  test_pipes1();
  gc_free();

  printf("------------- test pipes2\n");
  gc_init();
  test_pipes2();
  gc_free();
*/
  printf("------------- test multi\n");
  gc_init();
  test_multi();
  gc_free();

  return 0;
}
