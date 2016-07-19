;��������������������������������������������������������������������������������������������ͻ
;�                                                                                            �
;� PELock - Bartosz W�jcik                                                                    �
;�                                                                                            �
;� � przykladowy kod wtyczki                                                                  �
;� � skladnia fasm - pobierz fasm ze strony http://flatassembler.net                          �
;� � do czytania tego kodu najlepiej nadaje sie font terminal                                 �
;�                                                                                            �
;������������������������������������������������������͹support@pelock.com�͹www.pelock.com�ͼ

; pomocnicze makra
	macro pushs s
	{
		local after
		call after
		db s, 0
	after:
	}


; pliki naglowkowe
	include '%fasminc%\win32ax.inc'
	include '%fasminc%\macro\masm.inc'

; opis struktury interfejsu plugina
	include 'pelock_plugin.inc'


; sekcja danych
section '.data' data readable writable

	lpszPluginFile	db 'plugin_messagebox.bin',0
	lpszWriteOk	db 'Kod wtyczki zostal pomyslnie utworzony!',0
	lpszWriteErr	db 'Nie mozna utworzyc pliku z kodem wtyczki!',0

; sekcja kodu (z flagami ODCZYT-ZAPIS, tak ze mozna modyfikowac kod wtyczki w tej sekcji)
section '.text' code readable writable executable
start:

;����������������������������������������������������������������������������������������������
; zapisz kod wtyczki do pliku
;����������������������������������������������������������������������������������������������
	push	_plugin_procedure_size		; rozmiar kodu wtyczki
	push	_plugin_procedure		; procedura wtyczki
	push	lpszPluginFile			; nazwa pliku wyjsciowego
	call	_save_plugin			; zapisz

;����������������������������������������������������������������������������������������������
; sprawdz kod bledu z procedury _save_plugin i wyswietl odpowiedni komunikat
;����������������������������������������������������������������������������������������������
	mov	edx,lpszWriteOk
	mov	ecx,MB_ICONINFORMATION

	test	eax,eax 			; sprawdz kod bledu z _save_plugin
	je	@f				; jesli to 0, wyswietl informacje o sukcesie

	mov	edx,lpszWriteErr		; w innym wypadku informacje o bledzie
	mov	ecx,MB_ICONASTERISK
@@:
	push	ecx				; rodzaj okna informacyjnego
	push	lpszPluginFile			; jako tytul wyswietl nazwe pliku
	push	edx				; tekst wiadomosci
	push	0				; hWndOwner
	call	[MessageBox]			; wyswietl wiadomosc

;����������������������������������������������������������������������������������������������
; przed zakonczeniem programu, zasymuluj wywolanie kodu wtyczki
;����������������������������������������������������������������������������������������������
	push	_plugin_procedure
	call	_simulate_call

;����������������������������������������������������������������������������������������������
; zakoncz program
;����������������������������������������������������������������������������������������������
	push	0				; kod bledu
	call	[ExitProcess]			; zakoncz

;����������������������������������������������������������������������������������������������
;
; proc _save_plugin, lpszFilename, lpCodeBuffer, dwCodeBuffer
;
; [wej]
; lpszFilename - nazwa pliku, gdzie zostanie zapisany kod wtyczki
; lpCodeBuffer - wskaznik kodu wtyczki
; dwCodeBuffer - rozmiar kodu wtyczki
;
; [wyj]
; 0 - sukces, 1 - blad
;
; [modyfikowane rejestry]
; EAX, ECX, EDX
;
;����������������������������������������������������������������������������������������������

proc _save_plugin uses esi edi ebx, lpszFilename, lpCodeBuffer, dwCodeBuffer

	local	dwNumberOfBytesWritten dd ?	; zmienna lokalna

	sub	ebx,ebx 			; EBX = 0

	mov	esi,[lpszFilename]		; sprawdz parametr
	test	esi,esi
	je	_save_plugin_error

;����������������������������������������������������������������������������������������������
; utworz nowy plik
;����������������������������������������������������������������������������������������������
	push	ebx				; hTemplate
	push	FILE_ATTRIBUTE_NORMAL		; dwFlagsAndAttributes
	push	CREATE_ALWAYS			; dwCreationDistribution
	push	ebx				; lpSecurityAttributes
	push	ebx				; dwShareMode
	push	GENERIC_READ or GENERIC_WRITE	; dwDesiredAccess
	push	esi				; lpFileName
	call	[CreateFile]			; utworz nowy plik
	cmp	eax,-1				; sprawdz zwrocona wartosc (INVALID_HANDLE_VALUE)
	je	_save_plugin_error		;

	xchg	eax,edi 			; uchwyt pliku do EDI

;����������������������������������������������������������������������������������������������
; zapisz do pliku
;����������������������������������������������������������������������������������������������
	lea	eax,[dwNumberOfBytesWritten]

	push	ebx				; lpOverlapped
	push	eax				; lpNumberOfBytesWritten
	push	[dwCodeBuffer]			; nNumberOfBytesToWrite
	push	[lpCodeBuffer]			; lpBuffer
	push	edi				; hFile
	call	[WriteFile]			; zapisz kod wtyczki
	xchg	eax,esi 			; kod bledu

;����������������������������������������������������������������������������������������������
; zamknij plik
;����������������������������������������������������������������������������������������������
	push	edi				; uchwyt pliku
	call	[CloseHandle]			; zamknij plik

;����������������������������������������������������������������������������������������������
; sprawdz kod bledu z WriteFile
;����������������������������������������������������������������������������������������������
	test	esi,esi
	je	_save_plugin_error

	sub	eax,eax 			; 0 sukces
	jmp	_save_plugin_exit		; zwroc wartosc

_save_plugin_error:

	mov	eax,1				; zapisz kod bledu do EAX

_save_plugin_exit:

	ret					; wroc z kodem bledu
endp


;����������������������������������������������������������������������������������������������
;
; proc _simulate_call, lpPluginCode
;
; [wej]
; lpPluginCode - wskaznik do kodu wtyczki
;
; [wyj]
; brak
;
; [modyfikowane rejestry]
; EAX, ECX, EDX
;
;����������������������������������������������������������������������������������������������

proc _simulate_call, lpPluginCode

	local	lpPi PLUGIN_INTERFACE ?

;����������������������������������������������������������������������������������������������
; wypelnij strukture PLUGIN_INTERFACE
;����������������������������������������������������������������������������������������������
	lea	esi,[lpPi]
	assume	esi:PLUGIN_INTERFACE

; wewnetrzne dane
	mov	[esi.pe_imagebase],400000h	; baza obrazu w pamieci
	mov	[esi.pe_imagesize],1000h	; rozmiar obrazu
	mov	[esi.pe_temp],0 		; (na twoj uzytek)

; manipulacja na pamieci
;	mov	[esi.pe_memcpy],memcpy		; __stdcall void *memcpy(void * restrict s1, const void * restrict s2, size_t n);
;	mov	[esi.pe_memset],memset		; __stdcall void *memset(void *s, int c, size_t n);

; funkcje ciagow znakowych
;	mov	[esi.pe_strlen],strlen		; __stdcall size_t strlen(const char *s);
;	mov	[esi.pe_strcpy],strcpy		; __stdcall char *strcpy(char * restrict s1,const char * restrict s2);
;	mov	[esi.pe_strcat],strcat		; __stdcall char *strcat(char * restrict s1,const char * restrict s2);

; standardowe funkcje WinApi
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

	pushfd					; zachowaj wszystkie flagi
	pushad					; zachowaj wszystkie rejestry

	push	esi				; &PLUGIN_INTERFACE
	call	[lpPluginCode]			; wywolaj kod wtyczki

	popad					; przywroc wszystkie rejestry
	popfd					; przywroc wszystkie flagi

	ret					; powrot
endp


;����������������������������������������������������������������������������������������������
;
; proc _plugin_procedure, lpPluginInterface
;
; przykladowy kod wtyczki
;
; [wej]
; lpPluginInterface - wypelniona struktura interfejsu PELock'a
;
; [wyj]
; nie ma znaczenia
;
; [info]
; konwencja __stdcall, rejestr ESP musi byc zachowany, wszystkie inne rejestry
; moga byc zamazane (w tym EBP)
;
; struktura lpPluginStructure jest niszczona po wyjsciu z kodu wtyczki, nie mozna
; jej przekazywac jako np. parametr dla procedury watku etc.
;
;����������������������������������������������������������������������������������������������

proc _plugin_procedure, lpPluginInterface

	mov	esi,[lpPluginInterface] 	; wypelniona struktura PLUGIN_INTERFACE
	assume  esi:PLUGIN_INTERFACE

;����������������������������������������������������������������������������������������������
; zapytajmy uzytkownika, czy chce kontynuowac czy zakonczyc dzialanie programu
;����������������������������������������������������������������������������������������������
	push	MB_YESNO			; rodzaj okienka informacyjnego
	pushs	'Pytanie'			; adres powrotu bedzie wskazywal na
	pushs	'Czy chcesz kontynuowac?'	; tekst wiadomosci
	push	0				; hWndOwner
	call	[esi.pe_MessageBoxA]		; wyswietl wiadomosc

	cmp	eax,IDYES			; czy uzytkownik wybral "Tak"
	je	_continue_execution		; jesli tak, kontynuuj dzialanie, inaczej zakoncz

;����������������������������������������������������������������������������������������������
; zakoncz dzialanie aplikacji
;����������������������������������������������������������������������������������������������
	push	1				; kod bledu
	call	[esi.pe_ExitProcess]		; zakoncz proces aplikacji

;����������������������������������������������������������������������������������������������
; wroc z kodu wtyczki (dzialanie programu bedzie kontynuowane)
;����������������������������������������������������������������������������������������������
_continue_execution:

	ret					; wroc do kodu loader'a i kontynuuj
						; dzialanie
endp
_plugin_procedure_size = $-_plugin_procedure	; rozmiar kodu wtyczki

.end start
