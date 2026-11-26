; RUN: opt -passes=loop-vectorize -enable-vplan-native-path -enable-interleaved-mem-accesses -pass-remarks=loop-vectorize -pass-remarks-analysis=loop-vectorize -disable-output %s 2>&1 | FileCheck %s
; RUN: opt -passes=loop-vectorize -enable-vplan-native-path -enable-interleaved-mem-accesses -pass-remarks=loop-vectorize -pass-remarks-analysis=loop-vectorize -pragma-vectorize-scev-check-threshold=0 -disable-output %s 2>&1 | FileCheck %s --check-prefix=THRESHOLD
; RUN: opt -passes=loop-vectorize -enable-vplan-native-path -enable-interleaved-mem-accesses -pragma-vectorize-scev-check-threshold=0 -S %s | FileCheck %s --check-prefix=THRESHOLD-IR

; Remarks for outer loops whose interleave groups have a runtime stride.

; The stores do not form a full group, so the step of the pointer induction is
; a runtime value. The remark points at the induction.
; CHECK: remark: test.c:4:7: loop not vectorized: pointer induction with a non-constant step could not be vectorized
; THRESHOLD: remark: test.c:4:7: loop not vectorized: pointer induction with a non-constant step could not be vectorized
define void @store_group_ptr_iv_runtime_step_with_gap(ptr noalias %dst, i64 %step, i64 %N, i64 %M) !dbg !3 {
entry:
  br label %outer.header

outer.header:
  %i = phi i64 [ 0, %entry ], [ %i.next, %outer.latch ]
  %ptr.iv = phi ptr [ %dst, %entry ], [ %ptr.iv.next, %outer.latch ], !dbg !6
  br label %inner

inner:
  %j = phi i64 [ 0, %outer.header ], [ %j.next, %inner ]
  %j.next = add nuw nsw i64 %j, 1
  %inner.ec = icmp eq i64 %j.next, %M
  br i1 %inner.ec, label %outer.latch, label %inner

outer.latch:
  %t = trunc i64 %i to i32
  %d2 = getelementptr inbounds i8, ptr %ptr.iv, i64 8
  store i32 %t, ptr %ptr.iv, align 4
  store i32 %t, ptr %d2, align 4
  %ptr.iv.next = getelementptr inbounds i8, ptr %ptr.iv, i64 %step
  %i.next = add nuw nsw i64 %i, 1
  %outer.ec = icmp eq i64 %i.next, %N
  br i1 %outer.ec, label %exit, label %outer.header, !llvm.loop !10

exit:
  ret void
}

; A store group with the runtime stride %S. With a SCEV check threshold of 0,
; the loop is not versioned on %S == 2.
; CHECK: remark: test.c:12:3: vectorized outer loop (vectorization width: 4, interleaved count: 1)
; THRESHOLD: remark: test.c:12:3: vectorized outer loop (vectorization width: 4, interleaved count: 1)
; THRESHOLD-IR-LABEL: define void @store_group_runtime_stride(
; THRESHOLD-IR-NOT:     ident.check
; THRESHOLD-IR:         call void @llvm.masked.scatter
define void @store_group_runtime_stride(ptr noalias %dst, i64 %S, i64 %N, i64 %M) !dbg !7 {
entry:
  br label %outer.header

outer.header:
  %i = phi i64 [ 0, %entry ], [ %i.next, %outer.latch ]
  br label %inner

inner:
  %j = phi i64 [ 0, %outer.header ], [ %j.next, %inner ]
  %j.next = add nuw nsw i64 %j, 1
  %inner.ec = icmp eq i64 %j.next, %M
  br i1 %inner.ec, label %outer.latch, label %inner

outer.latch:
  %t = trunc i64 %i to i32
  %iS = mul nsw i64 %i, %S
  %d0 = getelementptr inbounds i32, ptr %dst, i64 %iS
  %d1 = getelementptr inbounds i8, ptr %d0, i64 4
  store i32 %t, ptr %d0, align 4
  store i32 %t, ptr %d1, align 4
  %i.next = add nuw nsw i64 %i, 1
  %outer.ec = icmp eq i64 %i.next, %N
  br i1 %outer.ec, label %exit, label %outer.header, !llvm.loop !13

exit:
  ret void
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2}

!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, emissionKind: LineTablesOnly)
!1 = !DIFile(filename: "test.c", directory: "/")
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = distinct !DISubprogram(name: "store_group_ptr_iv_runtime_step_with_gap", scope: !1, file: !1, line: 1, type: !4, unit: !0)
!4 = !DISubroutineType(types: !5)
!5 = !{}
!6 = !DILocation(line: 4, column: 7, scope: !3)
!7 = distinct !DISubprogram(name: "store_group_runtime_stride", scope: !1, file: !1, line: 10, type: !4, unit: !0)
!8 = !DILocation(line: 2, column: 3, scope: !3)
!9 = !DILocation(line: 12, column: 3, scope: !7)
!10 = distinct !{!10, !8, !11, !12}
!11 = !{!"llvm.loop.vectorize.width", i32 4}
!12 = !{!"llvm.loop.vectorize.enable"}
!13 = distinct !{!13, !9, !11, !12}
