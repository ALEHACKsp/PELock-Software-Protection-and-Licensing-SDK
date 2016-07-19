;��������������������������������������������������������������������������������������������ͻ
;�                                                                                            �
;� PELock - Bartosz W�jcik                                                                    �
;�                                                                                            �
;� � plugin sample code                                                                       �
;� � fasm syntax - get fasm from http://flatassembler.net                                     �
;� � best viewed with terminal font                                                           �
;�                                                                                            �
;������������������������������������������������������͹support@pelock.com�͹www.pelock.com�ͼ

; additional macros
	macro pushs s
	{
		local after
		call after
		db s, 0
	after:
	}

; include files
	include '%fasminc%\win32ax.inc'
	include '%fasminc%\macro\masm.inc'

; plugin structure description
	include 'pelock_plugin.inc'

; data section
section '.data' data readable writable

	lpszPluginFile	db 'plugin_messagebox.bin',0
	lpszWriteOk	db 'Plugin file successfully created!',0
	lpszWriteErr	db 'Cannot create file with plugin code!',0


; code section (with READ-WRITE flags, so you can modify plugin code in this section)
section '.text' code readable writable executable
start:

;����������������������������������������������������������������������������������������������
; save plugin code to the file
;����������������������������������������������������������������������������������������������
	push	_plugin_procedure_size		; plugin code size
	push	_plugin_procedure		; plugin procedure
	push	lpszPluginFile			; output filename
	call	_save_plugin			; save it

;����������������������������������������������������������������������������������������������
; check error code from _save_plugin and display message dialog
;����������������������������������������������������������������������������������������������
	mov	edx,lpszWriteOk
	mov	ecx,MB_ICONINFORMATION

	test	eax,eax 			; check error code from _save_plugin
	je	@f				; if its 0 then display success message

	mov	edx,lpszWriteErr		; otherwise error message
	mov	ecx,MB_ICONASTERISK
@@:
	push	ecx				; dialog type
	push	lpszPluginFile			; display filename as a caption
	push	edx				; text
	push	0				; hWndOwner
	call	[MessageBox]			; display message

;����������������������������������������������������������������������������������������������
; before exit simulate plugin call
;����������������������������������������������������������������������������������������������
	push	_plugin_procedure
	call	_simulate_call

;����������������������������������������������������������������������������������������������
; exit process
;����������������������������������������������������������������������������������������������
	push	0				; exit code
	call	[ExitProcess]			; exit

;����������������������������������������������������������������������������������������������
;
; proc _save_plugin, lpszFilename, lpCodeBuffer, dwCodeBuffer
;
; [in]
; lpszFilename - filename where to save plugin's code
; lpCodeBuffer - pointer to the plugin's code
; dwCodeBuffer - plugin code buffer size
;
; [out]
; 0 - success, 1 - errror
;
; [modified registers]
; EAX, ECX, EDX
;
;����������������������������������������������������������������������������������������������

proc _save_plugin uses esi edi ebx, lpszFilename, lpCodeBuffer, dwCodeBuffer

	local	dwNumberOfBytesWritten dd ?	; local variable

	sub	ebx,ebx 			; EBX = 0

	mov	esi,[lpszFilename]		; check parameter
	test	esi,esi
	je	_save_plugin_error

;����������������������������������������������������������������������������������������������
; create a new file
;����������������������������������������������������������������������������������������������
	push	ebx				; hTemplate
	push	FILE_ATTRIBUTE_NORMAL		; dwFlagsAndAttributes
	push	CREATE_ALWAYS			; dwCreationDistribution
	push	ebx				; lpSecurityAttributes
	push	ebx				; dwShareMode
	push	GENERIC_READ or GENERIC_WRITE	; dwDesiredAccess
	push	esi				; lpFileName
	call	[CreateFile]			 ; create new file
	cmp	eax,-1				; check return value (INVALID_HANDLE_VALUE)
	je	_save_plugin_error		;

	xchg	eax,edi 			; file handle to EDI

;����������������������������������������������������������������������������������������������
; write to file
;����������������������������������������������������������������������������������������������
	lea	eax,[dwNumberOfBytesWritten]

	push	ebx				; lpOverlapped
	push	eax				; lpNumberOfBytesWritten
	push	[dwCodeBuffer]			; nNumberOfBytesToWrite
	push	[lpCodeBuffer]			; lpBuffer
	push	edi				; hFile
	call	[WriteFile]			; write plugin's code
	xchg	eax,esi 			; error code

;����������������������������������������������������������������������������������������������
; close file
;����������������������������������������������������������������������������������������������
	push	edi				; file handle
	call	[CloseHandle]			; close file

;����������������������������������������������������������������������������������������������
; check error code from WriteFile
;����������������������������������������������������������������������������������������������
	test	esi,esi
	je	_save_plugin_error

	sub	eax,eax 			; 0 success
	jmp	_save_plugin_exit		; return value

_save_plugin_error:

	mov	eax,1				; store error code in EAX

_save_plugin_exit:

	ret					; return with error code
endp


;����������������������������������������������������������������������������������������������
;
; _simulate_call proc uses esi edi ebx, lpPluginCode:dword
;
; [in]
; lpPluginCode - pointer to the plugin's code
;
; [out]
; none
;
; [modified registers]
; EAX, ECX, EDX
;
;����������������������������������������������������������������������������������������������

proc _simulate_call uses esi edi ebx, lpPluginCode

	local	lpPi PLUGIN_INTERFACE ?

;����������������������������������������������������������������������������������������������
; fill out PLUGIN_INTERFACE structure
;����������������������������������������������������������������������������������������������
	lea	esi,[lpPi]
	assume	esi:PLUGIN_INTERFACE

; internal data
	mov	[esi.pe_imagebase],400000h	; module imagebase
	mov	[esi.pe_imagesize],1000h	; image size
	mov	[esi.pe_temp],0 		; (for your usage)

; memory manipulation
;	mov	[esi.pe_memcpy],memcpy		; __stdcall void *memcpy(void * restrict s1, const void * restrict s2, size_t n);
;	mov	[esi.pe_memset],memset		; __stdcall void *memset(void *s, int c, size_t n);

; string functions
;	mov	[esi.pe_strlen],strlen		; __stdcall size_t strlen(const char *s);
;	mov	[esi.pe_strcpy],strcpy		; __stdcall char *strcpy(char * restrict s1,const char * restrict s2);
;	mov	[esi.pe_strcat],strcat		; __stdcall char *strcat(char * restrict s1,const char * restrict s2);

; standard WinApi functions
	mov	eax,[GetModuleHandle]
	mov	[esi.pe_GetModuleHandleA],eax	; HMODULE GetModuleHandle(LPCTSTR lpModuleName);

	mov	eax,[GetModuleFileName]
	mov	[esi.pe_GetModuleFileNameA],eax ; DWORD GetModuleFileName(HMODULE hModule, LPTSTR lpFilename, DWORD nSize);

	mov	eax,[LoadLibrary]
	mov	[esi.pe_LoadLibraryA],eax	; HINSTANCE LoadLibrary(LPCTSTR lpLibFileName);

	mov	eax,[FreeLibrary]
	mov	[esi.pe_FreeLibrary],eax	; BOOL FreeLibrary(HMODULE hLibModule);

	mov	eax,[GetProcAddress]
	mov	[esi.pe_GetProcAddress],eax	; FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);

	mov	eax,[VirtualAlloc]
	mov	[esi.pe_VirtualAlloc],eax	; LPVOID VirtualAlloc(LPVOID lpAddress, DWORD dwSize, DWORD flAllocationType, DWORD flProtect);

	mov	eax,[VirtualFree]
	mov	[esi.pe_VirtualFree],eax	; BOOL VirtualFree(LPVOID lpAddress, DWORD dwSize, DWORD dwFreeType);

	mov	eax,[MessageBox]
	mov	[esi.pe_MessageBoxA],eax	; int MessageBox(HWND hWnd, LPCTSTR lpText, LPCTSTR lpCaption, UINT uType);

	mov	eax,[wsprintf]
	mov	[esi.pe_wsprintfA],eax		; int wsprintf(LPTSTR lpOut, LPCTSTR lpFmt, ...);

	mov	eax,[CreateThread]
	mov	[esi.pe_CreateThread],eax	; HANDLE CreateThread(LPSECURITY_ATTRIBUTES lpThreadAttributes, DWORD dwStackSize, LPTHREAD_START_ROUTINE lpStartAddress, LPVOID lpParameter, DWORD dwCreationFlags, LPDWORD lpThreadId);

	mov	eax,[ExitProcess]
	mov	[esi.pe_ExitProcess],eax	; VOID ExitProcess(UINT uExitCode);

	pushfd					; save all flags
	pushad					; save all registers

	push	esi				; &PLUGIN_INTERFACE
	call	[lpPluginCode]			; call plugin code

	popad					; restore all registers
	popfd					; restore all flags

	ret					; return
endp


;����������������������������������������������������������������������������������������������
;
; proc _plugin_procedure, lpPluginInterface
;
; sample plugin code
;
; [in]
; lpPluginInterface - filled PELock's plugin interface structure
;
; [out]
; you can return whatever you want
;
; [modified registers]
; EAX, ECX, EDX
;
; [info]
; __stdcall calling convention, you must preserve ESP register, all other registers
; can be destroyed (including EBP)
;
; lpPluginStructure is destroyed after return from the plugin code, so you can't
; pass it as a param to threads etc.
;
;����������������������������������������������������������������������������������������������

proc _plugin_procedure uses esi edi ebx, lpPluginInterface

	mov	esi,[lpPluginInterface] 	; interface pointer
	assume	esi:PLUGIN_INTERFACE

;����������������������������������������������������������������������������������������������
; let's ask user if he want to continue or exit
;����������������������������������������������������������������������������������������������
	push	MB_YESNO			; dialog type
	pushs	'Question'			; caption
	pushs	'Would you like to continue?'	; text
	push	0				; hWndOwner
	call	[esi.pe_MessageBoxA]		; display message

	cmp	eax,IDYES			; did user select "Yes"
	je	_continue_execution		; if so, continue

;����������������������������������������������������������������������������������������������
; exit
;����������������������������������������������������������������������������������������������
	push	1				; error code
	call	[esi.pe_ExitProcess]		; exit process

;����������������������������������������������������������������������������������������������
; return from plugin code (continue execution)
;����������������������������������������������������������������������������������������������
_continue_execution:

	ret					; return to the loader's code and continue
						; execution
endp
_plugin_procedure_size = $-_plugin_procedure	; plugin code size

.end start
