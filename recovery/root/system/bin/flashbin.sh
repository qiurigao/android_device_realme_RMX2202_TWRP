#!/system/bin/sh
###丐版强刷脚本
###2022.09.08
export TMPDIR=/data/tmp_payload_dir
rm -rf $TMPDIR
mkdir $TMPDIR
mkdir $TMPDIR/logical_image
mkdir $TMPDIR/unpack_image
mkdir $TMPDIR/install_image 
echo " 正在提取分区"
/system/bin/payload_dumper -o $TMPDIR/unpack_image "$1"
mv -f $TMPDIR/unpack_image/system.img $TMPDIR/logical_image 
mv -f $TMPDIR/unpack_image/product.img $TMPDIR/logical_image 
mv -f $TMPDIR/unpack_image/odm.img $TMPDIR/logical_image 
mv -f $TMPDIR/unpack_image/system_ext.img $TMPDIR/logical_image 
mv -f $TMPDIR/unpack_image/vendor.img $TMPDIR/logical_image 
mv -f $TMPDIR/unpack_image/my_* $TMPDIR/logical_image
mv -f $TMPDIR/unpack_image/*_dlkm.img $TMPDIR/logical_image
mv -f $TMPDIR/unpack_image/*.img $TMPDIR/install_image 

echo " 创建super.img"
WorkDir=$TMPDIR/logical_image
SuperImage=$TMPDIR/unpack_image/super.img
argvs="--metadata-size 65536 --super-name super --sparse  --virtual-ab  --metadata-slots 2 "
##10200547328
superSize=$(lpdump -j | sed -n '/super/{N;p}' | tail -1 | awk -F '"' '{print$(NF-1)}')
argvs+="--device super:$superSize "
group_size=0
for image in $(ls $WorkDir/*.img );do 
	img_size=$(wc -c <$image) 
	imgName=$(basename $image)
	item_partition=${imgName%.img}
	group_size=`expr ${img_size} + ${group_size}`
	argvs+="--partition "$item_partition"_a:readonly:$img_size:main --image "$item_partition"_a=$image --partition "$item_partition"_b:readonly:0:main "
	echo $img_size $imgName $item_partition $group_size
done
argvs+="--group main:$group_size "
argvs+="--output $SuperImage"
if ( lpmake $argvs 2>&1 ); then
    echo "\n创建super.img成功!\n"
fi


echo " 写入底层"
for image in $(ls $TMPDIR/install_image/*.img );do 
	imgName=$(basename $image)
	partition=${imgName%.img}
    echo "正在刷写分区${partition}_a"
	dd if=$image of=/dev/block/by-name/${partition}_a 
    echo "正在刷写分区${partition}_b"
	dd if=$image of=/dev/block/by-name/${partition}_b 
done

echo "正在刷写super,请耐心等待"
simg2img $TMPDIR/unpack_image/super.img /dev/block/by-name/super 

echo "正在设置A槽启动"
/system/bin/bootctl set-active-boot-slot 0

echo "正在清理文件"
#rm -rf  $TMPDIR

echo " 完成"