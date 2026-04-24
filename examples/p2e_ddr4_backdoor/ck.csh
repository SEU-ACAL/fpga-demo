#!/bin/csh -f
# Compare case.ref vs $des_file
set des_file = "case.result"
rm $des_file
set mfb = `pwd | grep _mfb`
if ($mfb == "") then
  if (-f vcom.log) then
    set m = `grep -c 'error]' vcom.log`
    if ($m == 0) then
      echo "PASS : check_point.result is the same with golden file check_point.ref" >> $des_file
    else
      echo "FAIL: vcom.log has some errors" >> $des_file
    endif
  else
    echo "FAIL: vcom.log is not generated" >> $des_file
  endif

else
  echo "===========================check normal test============================"
  echo "===========================check normal test============================" >> $des_file
  if (-f check_point1.result) then
    diff check_point1.result check_point1.ref > check_point.diff
    if (-z check_point.diff) then
      echo "PASS: check_point1.result is the same with golden file check_point1.ref" >> $des_file
    else
      echo "FAIL: check_point1.result is different with golden file check_point1.ref" >> $des_file
    endif
  else
    echo "FAIL: check_point1.result is not generated" >> $des_file
  endif

  if (-f check_point2.result) then
    diff check_point2.result check_point2.ref > check_point.diff
    if (-z check_point.diff) then
      echo "PASS: check_point2.result is the same with golden file check_point2.ref" >> $des_file
    else
      echo "FAIL: check_point2.result is different with golden file check_point2.ref" >> $des_file
    endif
  else
    echo "FAIL: check_point2.result is not generated" >> $des_file
  endif

  if (-f check_point3.result) then
    diff check_point3.result check_point3.ref > check_point.diff
    if (-z check_point.diff) then
      echo "PASS: check_point3.result is the same with golden file check_point3.ref" >> $des_file
    else
      echo "FAIL: check_point3.result is different with golden file check_point3.ref" >> $des_file
    endif
  else
    echo "FAIL: check_point3.result is not generated" >> $des_file
  endif

  if (-f check_point4.result) then
    diff check_point4.result check_point4.ref > check_point.diff
    if (-z check_point.diff) then
      echo "PASS: check_point4.result is the same with golden file check_point4.ref" >> $des_file
    else
      echo "FAIL: check_point4.result is different with golden file check_point4.ref" >> $des_file
    endif
  else
    echo "FAIL: check_point4.result is not generated" >> $des_file
  endif
  
  if (-f axi_wr.result) then
    diff axi_wr.result axi_wr.ref > check_point.diff
    if (-z check_point.diff) then
      echo "PASS: axi_wr.result is the same with golden file axi_wr.ref" >> $des_file
    else
      echo "FAIL: axi_wr.result is different with golden file axi_wr.ref" >> $des_file
    endif
  else
    echo "FAIL: axi_wr.result is not generated" >> $des_file
  endif
  
  echo "===========================check normal 16G test============================"
  echo "===========================check normal 16G test============================" >> $des_file
  set i = 0
  set sum = 9
  while($i<$sum)
      set ref_file = "back_door_read_${i}.ref"
      set result_file = "back_door_read_${i}.result"
      if (-f $result_file ) then
          diff  $ref_file $result_file > ${result_file}.diff
          if (-z ${result_file}.diff) then
              echo "PASS : $result_file is the same with golden file $ref_file" >> $des_file
          else
            echo "FAIL : $result_file is different with golden file $ref_file" >> $des_file
          endif
      else
        echo "FAIL: $result_file is not generate" >> $des_file
      endif
     @ i++
  end
  
  echo "===== check debug 0p5G data  regression ====="
  echo "===== check debug 0p5G data  regression =====" >> $des_file
  set ref_file = "data_0p5G_test.ref"
  set result_file = "data_0p5G_test.result"
  if (-f $result_file ) then
      diff  $ref_file $result_file > ${result_file}.diff
      if (-z ${result_file}.diff) then
          echo "PASS : $result_file is the same with golden file $ref_file" >> $des_file
      else
        echo "FAIL : $result_file is different with golden file $ref_file" >> $des_file
      endif
  else
    echo "FAIL: $result_file is not generate" >> $des_file
  endif

endif
