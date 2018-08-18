.model small                    
.stack 100h                     
.data          
	; Messages
	end_game_mes db ' END GAME  '
	dragon_win_mes db ' Dragon VIN'
	snake_win_mes db ' Snake VIN '
	double_kill_mes db ' DOUBLE KILL '
	new_line db 13, 10, '$'
	mes_offset dw 00
    
	; Errors
    open_error_mes db 'Unable to open file!', '$'
    read_error_mes db 'Wrong file content!', '$'
    read_count_error_mes db 'Wrong symbols count in file!', '$'
	
	; Animal:
	rule db 1
	animal dw 0ffh dup('$')
	animal_length dw ?
	
	; Snake:
	snake_rule db 'd'
	snake dw 0ffh dup('$')
	snake_length dw ?
	
	; Dragon
	dragon_rule db 'a'
	dragon dw 0ffh dup('$')
	dragon_length dw ?
	
	eat_point_1 dw 930+81
	; *
	eat_point_2 dw 600		; +
	eat_point_3 dw 1360	; .
	eat_timeout dw 3
	
	; File info
	level_file db 'level.txt', 0
	end_file db 'endfile.txt', 0
    handle dw ?
	raw_content db 0fffh dup('$')
	content_length dw ?	
	
.code
	; just print command
    print proc
        mov ah,09h
        int 21h
        ret
    print endp
	
	; just exit command
	exit proc
		mov ah,4Ch               
		int 21h       
    exit endp
	
	end_scrin proc
		; Open endfile and show endscrin
		mov dx, offset end_file
		call open_file
		call read_file
		
		; Write end mess
		mov cx,11			; symbols count to write
		; setting symbols in raw_content(writing)
		set_symbol:
			mov di,cx
			add di,mes_offset
			mov al,[di]
			mov di,1005
			add di,cx
			mov byte ptr raw_content[di],al
		loop set_symbol
		
		; Show endscrin
		call print_raw_content
		
		ret
	end_scrin endp
	
	open_file proc      
		; Открытие файла
		mov ah,3dh
		mov al,0h
		int 21h
		jc open_error 											
		; Запись дескриптора
		mov handle,ax 					
		ret
		
		open_error:
			mov dx, offset open_error_mes
			call print
			call exit
	open_file endp
	
	read_file proc
		; Чтение файла
		mov ah,3fh											
		mov bx,handle
		mov cx,0fffh
		mov dx,offset raw_content
		int 21h
		
		; Обработка возможных ошибок
		jc read_error
		cmp ax, cx
		je read_count_error
		
		; Количество прочитанных символов
		mov content_length, ax
		ret
	
		read_error:
			mov dx,offset read_error_mes
			call print
			call exit
		read_count_error:
			mov dx,offset read_count_error_mes
			call print
			call exit
	read_file endp
	
	; Print game in console
	print_raw_content proc
		mov dx,offset raw_content
		call print
		
		mov dx, offset new_line
		call print
		ret
	print_raw_content endp 
	
	; Wait some times
	timer proc
		mov dx,0
		time_next:      
			mov cx,0bfh
			time_in_time:
			loop time_in_time
			
			inc dx
			cmp dx,5000h
			je time_ret
		jmp time_next
		
		time_ret:
			ret
	timer endp
	
	; read new symbol to rule, if it is
	read_rule proc
		xor ax,ax
		; check symbol
		mov ah,11h
		int 16h
		jnz is_tapped
		
		ret

		is_tapped:
			; get new rule
			mov ah,10h
			int 16h
			; protect of keyboard handling
			mov ah,11h
			int 16h
			jnz is_tapped
			
			mov rule, al
			
			; check who is ruled
			; snake
			cmp al,'w'
			je set_snake_rule
			cmp al,'d'
			je set_snake_rule
			cmp al,'s'
			je set_snake_rule
			cmp al,'a'
			je set_snake_rule
			
			; dragon
			cmp al,'o'
			mov ah,'w'
			je set_dragon_rule
			cmp al,';'
			mov ah,'d'
			je set_dragon_rule
			cmp al,'l'
			mov ah,'s'
			je set_dragon_rule
			cmp al,'k'
			mov ah,'a'
			je set_dragon_rule
			
			; no one is ruled. go out
			ret
			set_snake_rule:
				mov snake_rule,al
				ret
				
			set_dragon_rule:
				mov dragon_rule,ah
				ret
	read_rule endp
	
	; make step for one animal
	step proc
		mov di,animal
		mov dx,di
		
		mov al,rule
		
		cmp al,'w'
		je up
		cmp al,'d'
		je rigth
		cmp al,'s'
		je down
		cmp al,'a'
		je left
		ret			
		
		up:
			mov di,[di]
			sub di,81
			jmp move
		rigth:
			mov di,[di]
			add di,1
			jmp move
		down:
			mov di,[di]
			add di,81
			jmp move
		left:
			mov di,[di]
			sub di,1			
			jmp move
			
		move:
			; errors handling
			mov al, byte ptr raw_content[di]
			cmp al, "="
			je do_not_move
			cmp al, "|"
			je do_not_move
			cmp al, "#"
			je do_not_move
			cmp al, "%"
			je touth_death
			cmp al, "@"
			je touth_death
			cmp al, "Z"
			je do_not_move
			cmp al, "*"
			je eating
			cmp al, "."
			je eating
			cmp al, "+"
			je eating
			
			start_moving:
				mov dx,di
				mov cx,animal_length
				inc cx
				mov si,0
			
			move_body:
				; get animal body index
				mov di,animal
				add di,si
				
				; change body
				mov ax,[di]; remember
				mov [di],dx		; set
				mov dx,ax			; remember new
				add si, 2
			loop move_body
			ret
			
		do_not_move:
			ret
			
		eating:
			mov ax, animal_length
			inc ax
			mov animal_length,ax
		jmp start_moving
					
		touth_death:
			call death
	step endp
	
	; if snake touch dragons head or dragon touch snakes head
	death proc
		mov ax,snake_length
		cmp ax,dragon_length
		jz both_death
		jb snake_death
		
		mov ax, offset snake_win_mes
		mov mes_offset,ax
		call end_scrin
		call exit
			
		both_death:
			mov ax, offset double_kill_mes
			mov mes_offset,ax
			call end_scrin
			call exit
		
		snake_death:
			mov ax, offset dragon_win_mes
			mov mes_offset,ax
			call end_scrin
			call exit
	death endp
	
	set_eat proc
		mov cx, eat_timeout
		dec cx
		cmp cx,0
		jz new_eat
		
		cmp cx,35
		jz set_eat_point_1
		
		cmp cx,60
		jz set_eat_point_2
		
		cmp cx,70
		jz set_eat_point_3
		
		jmp end_set_eat
		
		set_eat_point_1:
			mov ax, snake
			mov eat_point_1,ax
			jmp end_set_eat
			
		set_eat_point_2:
			mov ax, dragon
			mov eat_point_2,ax
			jmp end_set_eat
		
		set_eat_point_3:
			mov ax, snake
			mov eat_point_3,ax
			jmp end_set_eat
			
		end_set_eat:
			mov eat_timeout, cx
			ret
		
		new_eat:
			mov cx, 90
			mov eat_timeout, cx
			
			mov di, eat_point_1
			add di, offset raw_content
			mov byte ptr [di],'*'
			
			mov di, eat_point_2
			add di, offset raw_content
			mov byte ptr [di],'+'
			
			mov di, eat_point_3
			add di, offset raw_content
			mov byte ptr [di],'.'
			
			ret
	set_eat endp
	
	set_snake proc
		; Set head
		mov di,snake
		mov raw_content + di,'%'
		
		; Set body
		mov cx,snake_length
		mov bl,2						
		set_body:
			mov ax,cx
			mul bl
			mov di,ax
			mov di,snake[di]
			mov raw_content + di,'#'
		loop set_body
		
		; Set tail void
		mov ax,snake_length
		mul bl
		mov di,ax
		mov di,snake[di]

		mov raw_content + di,' '
		
		ret
	set_snake endp
	
	set_dragon proc
		; Set head
		mov di,dragon
		mov raw_content + di,'@'
		
		; Set body
		mov cx,dragon_length
		dec cx
		mov bl,2						
		set_dragon_body:
			mov ax,cx
			mul bl
			mov di,ax
			mov di,dragon[di]
			mov raw_content + di,'Z'
		loop set_dragon_body
		
		; Set tail void
		mov ax,dragon_length
		mul bl
		mov di,ax
		mov di,dragon[di]
		
		; check clearing
		mov al,raw_content + di
		cmp al,'Z'
		jz do_clear
		ret
		
		do_clear:
			mov raw_content + di,' '
			ret
	set_dragon endp
	
	; all work with snake
	snake_RUN proc
		; move snake
		mov animal,offset snake
		mov ax,snake_length
		mov animal_length,ax
		mov al,snake_rule
		mov rule,al
		
		
		call step
		call set_snake
		
		; set new snake length
		mov ax,animal_length
		mov snake_length,ax
		
		ret
	snake_RUN endp
	
	; all work with dragon
	dragon_RUN proc
		; move dragon
		mov animal,offset dragon
		mov ax,dragon_length
		mov animal_length,ax
		mov al,dragon_rule
		mov rule,al
		
		call step
		call set_dragon
		
		; set new dragon length
		mov ax,animal_length
		mov dragon_length,ax
		
		ret
	dragon_RUN endp
	
	main proc
		mov ax,@data
		mov ds,ax
		
		mov dx, offset level_file
		call open_file
		call read_file

		mov snake, 1002-15
		mov snake[1*2], 1001-15
		mov snake[2*2], 1000-15
		mov snake[3*2], 999-15
		mov snake[4*2], 998-15
		mov snake[5*2], 997-15
		mov snake[6*2], 996-15
		mov snake[7*2], 995-15
		mov snake[8*2], 994-15
		mov snake[9*2], 993-15
		mov snake[10*2], 992-15
		mov snake[11*2], 991-15
		mov snake_length, 11
		
		mov dragon, 1020+15
		mov dragon[1*2], 1021+15
		mov dragon[2*2], 1022+15
		mov dragon[3*2], 1023+15
		mov dragon[4*2], 1024+15
		mov dragon[5*2], 1025+15
		mov dragon[6*2], 1026+15
		mov dragon[7*2], 1027+15
		mov dragon[8*2], 1028+15
		mov dragon[9*2], 1029+15
		mov dragon[10*2], 1030+15
		mov dragon[11*2], 1031+15
		mov dragon_length, 11

		
		run:
			; print game in console
			call print_raw_content
			
			; read new rule symbol
			call read_rule			
			; check end
			mov al,rule 
			cmp al,1Bh
			je ex
			
			call set_eat
			call snake_RUN
			call dragon_RUN
			
			; wait some time 
			call timer				
		jmp run		
		
		ex:
			mov ax, offset end_game_mes
			mov mes_offset,ax
			call end_scrin
			call exit

	main endp
end main