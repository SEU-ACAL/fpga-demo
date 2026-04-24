
puts "========= debug 0p5G data regression =========="

design .
hw_server .
set_phc_vol -id 0.0 -bank 3,4,5 -voltage 1.2
download
run -nowait
#get_register 0 0 0x480
#force channel_sel 1
set result_file_name "data_0p5G_test.result"
puts "rm old log file"
if {[file exists $result_file_name]} {
  exec rm -r $result_file_name
} 
if {[file exists run_backdoor.log]} {
  exec rm -r run_backdoor.log
}
#exec sed "s#-start .*#-start ${addr_begin} -end ${addr_end} #g" debug_1ddr_TestNormal.tcl -i
#exec sed "s#-channel \[0-9\]#-channel ${channel}#g" debug_1ddr_TestNormal.tcl -i
set i 1
set channel 0
set addr_begin  0
set len  536870911
set addr_end  [expr $addr_begin + $len]
set txt_addr_begin [format "%x" $addr_begin]
puts "addr_begin:$addr_begin  len:$len  addr_end:$addr_end  txt_addr_begin:$txt_addr_begin"

#test begin block addr
puts "========== test begin block addr  ========="
set addr_begin  0
set addr_end  [expr $addr_begin + $len]
set txt_addr_begin [format "%x" $addr_begin]
exec rm -r data_0p5G.ref
exec touch data_0p5G.ref
if {$addr_begin == 0} {
  exec echo "@0" >>  data_0p5G.ref 
  } else {
  exec echo "@0x${txt_addr_begin}" >> data_0p5G.ref
}
exec cat data_0p5G.txt >> data_0p5G.ref
after 1000
memory -write -fpga 0.A -channel $channel -file data_0p5G.ref
memory -read  -fpga 0.A -channel $channel -file data_0p5G.result -start $addr_begin -end $addr_end 
after 1000
exec diff -i data_0p5G.result data_0p5G.ref > check_point.diff
exec echo "========== test begin block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}
#test readf
memory -write -fpga 0.A -channel $channel -file data_0p5G_fread_addr1.ref -format %readf
memory -read  -fpga 0.A -channel $channel -file data_0p5G_fread_addr1.result -format %readf -start $addr_begin -end $addr_end
after 1000
exec diff -i data_0p5G_fread_addr1.ref data_0p5G_fread_addr1.result > check_point.diff
exec echo "========== test begin block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}


set i  [expr $i + 1]
#test last block addr
puts "========== test last block addr  ========="
set addr_begin  16642998272
set addr_end  [expr $addr_begin + $len]
set txt_addr_begin [format "%x" $addr_begin]
exec rm -r data_0p5G.ref
exec touch data_0p5G.ref
if {$addr_begin == 0} {
  exec echo "@0" >>  data_0p5G.ref
  } else {
  exec echo "@0x${txt_addr_begin}"  >>  data_0p5G.ref
}
exec cat data_0p5G.txt >> data_0p5G.ref

after 1000
memory -write -fpga 0.A -channel $channel -file data_0p5G.ref
memory -read  -fpga 0.A -channel $channel -file data_0p5G.result -start $addr_begin -end $addr_end 
after 1000
exec diff -i data_0p5G.result data_0p5G.ref > check_point.diff
exec echo "========== test last block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}
#test readf
memory -write -fpga 0.A -channel $channel -file data_0p5G_fread_addr2.ref -format %readf
memory -read  -fpga 0.A -channel $channel -file data_0p5G_fread_addr2.result -format %readf -start $addr_begin -end $addr_end
after 1000
exec diff -i data_0p5G_fread_addr2.ref data_0p5G_fread_addr2.result > check_point.diff
exec echo "========== test begin block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}


set i  [expr $i + 1]
#test not 2^n addr
puts "========== test not 2^n addr  ========="
set addr_begin  5
set addr_end  [expr $addr_begin + $len]
set txt_addr_begin [format "%x" $addr_begin]
exec rm -r data_0p5G.ref
exec touch data_0p5G.ref
if {$addr_begin == 0} {
  exec echo "@0" >>  data_0p5G.ref
  } else {
  exec echo "@0x${txt_addr_begin}"  >> data_0p5G.ref
}
exec cat data_0p5G.txt >> data_0p5G.ref

after 1000
memory -write -fpga 0.A -channel $channel -file data_0p5G.ref
memory -read  -fpga 0.A -channel $channel -file data_0p5G.result -start $addr_begin -end $addr_end 
after 1000
exec diff -i data_0p5G.result data_0p5G.ref > check_point.diff
exec echo "========== test not 2^n addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}
#test readf
memory -write -fpga 0.A -channel $channel -file data_0p5G_fread_addr3.ref -format %readf
memory -read  -fpga 0.A -channel $channel -file data_0p5G_fread_addr3.result -format %readf -start $addr_begin -end $addr_end
after 1000
exec diff -i data_0p5G_fread_addr3.ref data_0p5G_fread_addr3.result > check_point.diff
exec echo "========== test begin block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}


set i  [expr $i + 1]
set addr_begin  12884901875
set addr_end  [expr $addr_begin + $len]
set txt_addr_begin [format "%x" $addr_begin]
exec rm -r data_0p5G.ref
exec touch data_0p5G.ref
if {$addr_begin == 0} {
  exec echo "@0" >>  data_0p5G.ref
  } else {
  exec echo "@0x${txt_addr_begin}" >>  data_0p5G.ref
}
exec cat data_0p5G.txt >> data_0p5G.ref

after 1000
memory -write -fpga 0.A -channel $channel -file data_0p5G.ref
memory -read  -fpga 0.A -channel $channel -file data_0p5G.result -start $addr_begin -end $addr_end 
after 1000
exec diff -i data_0p5G.result data_0p5G.ref > check_point.diff
exec echo "========== test not 2^n addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}
#test readf
memory -write -fpga 0.A -channel $channel -file data_0p5G_fread_addr4.ref -format %readf
memory -read  -fpga 0.A -channel $channel -file data_0p5G_fread_addr4.result -format %readf -start $addr_begin -end $addr_end
after 1000
exec diff -i data_0p5G_fread_addr4.ref data_0p5G_fread_addr4.result > check_point.diff
exec echo "========== test begin block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}


set i  [expr $i + 1]
#test is 2^n addr
puts "========== test is 2^n addr  ========="
set addr_begin  12884901888
set addr_end  [expr $addr_begin + $len]
set txt_addr_begin [format "%x" $addr_begin]
exec rm -r data_0p5G.ref
exec touch data_0p5G.ref
if {$addr_begin == 0} {
  exec echo "@0" >>  data_0p5G.ref
  } else {
  exec echo "@0x${txt_addr_begin}"  >> data_0p5G.ref
}
exec cat data_0p5G.txt >> data_0p5G.ref

after 1000
memory -write -fpga 0.A -channel $channel -file data_0p5G.ref
memory -read  -fpga 0.A -channel $channel -file data_0p5G.result -start $addr_begin -end $addr_end 
after 1000
exec diff -i data_0p5G.result data_0p5G.ref > check_point.diff
exec echo "========== test is 2^n addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}
#test readf
memory -write -fpga 0.A -channel $channel -file data_0p5G_fread_addr5.ref -format %readf
memory -read  -fpga 0.A -channel $channel -file data_0p5G_fread_addr5.result -format %readf -start $addr_begin -end $addr_end
after 1000
exec diff -i data_0p5G_fread_addr5.ref data_0p5G_fread_addr5.result > check_point.diff
exec echo "========== test begin block addr  =========" >> $result_file_name
if { [file size check_point.diff]  == 0} {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
} else {
  exec echo "TEST READF: $i  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
}


#test full addr
puts "========== test full addr  ========="
set len_1 [expr $len + 1]
for {set a 0} {$a<32} {incr a} {
  set addr_begin [expr $a * $len_1]
  set addr_end  [expr $addr_begin + $len]
  set txt_addr_begin [format "%x" $addr_begin]
  exec rm -r data_0p5G.ref
  exec touch data_0p5G.ref
  if {$addr_begin == 0} {
    exec echo "@0" >>  data_0p5G.ref
    } else {
    exec echo "@0x${txt_addr_begin}"  >>  data_0p5G.ref
  }
  exec cat data_0p5G.txt >> data_0p5G.ref

  puts "test full addr:$a ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end"
  after 1000

  set begin [clock milliseconds];
  memory -write -fpga 0.A -channel $channel -file data_0p5G.ref
  set used [expr  [clock milliseconds] - $begin];
  puts "\[INFO\] backdoor write time : $used"
  set begin [clock milliseconds];
  memory -read  -fpga 0.A -channel $channel -file data_0p5G.result -start $addr_begin -end $addr_end
  puts "\[INFO\] backdoor read time : $used"
  set begin [clock milliseconds];
  after 1000
  exec diff -i data_0p5G.result data_0p5G.ref > check_point.diff
 exec echo "========== test is 2^n addr  =========" >> $result_file_name
  if { [file size check_point.diff]  == 0} {
    exec echo "TEST FULL ADDR: $a  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   PASS " >> $result_file_name
  } else {
    exec echo "TEST FULL ADDR: $a  ADDR_BEGIN: $addr_begin  ADDR_END: $addr_end   *****FAIL*****" >> $result_file_name
  }
}
#exit
