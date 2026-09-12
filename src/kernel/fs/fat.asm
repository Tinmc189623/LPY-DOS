; ============================================================================
;  fat.asm — FAT12/FAT16 文件系统与文件 API
;  文件系统服务（INT 21h AH=3C~57）
; ============================================================================

; ----------------------------------------------------------------------------
;  FAT 相关变量
; ----------------------------------------------------------------------------
dir_state_first dw 0            ; 目录枚举：起始簇（0=根目录）
dir_state_pos   dw 0            ; 目录枚举：当前项序号
; 查找结果
find_firstclu   dw 0
find_size       dd 0
find_attr       db 0
find_dirsector  dw 0            ; 目录项所在扇区 LBA
find_diroff     dw 0            ; 目录项在扇区内偏移
find_name       db 11 dup(0)    ; 11 字节文件名
; 路径解析临时
name_buf        db 13 dup(0)    ; 8.3 分量缓冲
norm_buf        db 11 dup(0)    ; 规范化 11 字节名
; 文件读写临时
read_dst_seg    dw 0
read_dst_off    dw 0
temp_clusoff    dw 0
temp_sector     dw 0
temp_off        dw 0
temp_remain     dw 0
; findfirst/findnext 状态
search_pattern  db 13 dup(0)    ; 搜索模式（转小写 8.3，0 结尾）
search_first    dw 0            ; 搜索起始目录簇
search_pos      dw 0            ; 当前搜索项序号


; ============================================================================
;  子模块（按 include 顺序拼接为完整模块；勿在 include 间插代码，新内容进对应子模块）
; ============================================================================
include 'fat_chain.asm'
include 'fat_dir.asm'
include 'fat_name.asm'
include 'fat_find.asm'
include 'fat_handle.asm'
include 'fat_newfile.asm'
include 'fat_fops.asm'
include 'fat_search.asm'
include 'fat_dirmgmt.asm'
