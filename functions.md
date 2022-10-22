# Functions Mermaid Diagram

The following diagram shows the first few layers deep (breadth-first) of functions that are invoked by the main function loop.

```mermaid
%% Top Node 
graph LR

%% Functions
%% idt(janet-termios)
    idt.1(enable-raw-mode)
    idt.2(read-key)
    idt.3(disable-raw-mode)
    idt.4(get-window-size)

id1(main)
    id1.1(init)
        %% idt.1(enable-raw-mode)
        id1.1.1(reset-editor-state)
            %% idt.4(get-window-size)
        id1.1.2(editor-open)
    
    id1.2(editor-refresh-screen)
        id1.2.1(update-screen-sizes)
        id1.2.2(editor-scroll)
        id1.2.3(editor-update-rows)
            id1.2.3.1(render-tabs)
            id1.2.3.2(slice-rows)
            id1.2.3.3(apply-h-scroll)
            id1.2.3.4(trim-to-width)
            id1.2.3.5(add-syntax-hl)
            id1.2.3.6(add-search-hl)
            id1.2.3.7(add-select-hl)
            id1.2.3.8(fill-empty-rows)
            id1.2.3.9(add-welcome-message)
            id1.2.3.10(apply-margin)
            id1.2.3.11(add-status-bar)
            id1.2.3.12(join-rows)
        id1.2.4(get-margin)
    id1.3(editor-process-keypress)
        %% idt2(read-key)
        id1.3.1{{keymap}}
            id1.3.1.1(ctrl-key functions)
                id1.3.1.1.1(close-file) 
                id1.3.1.1.2(toggle-line-numbers)
                id1.3.1.1.3(load-file-modal)
                id1.3.1.1.4(save-file)
                id1.3.1.1.5(save-file-as)
                id1.3.1.1.6(enter-debugger)
                id1.3.1.1.7(close-file)
                id1.3.1.1.8(find-in-text-modal)
                id1.3.1.1.9(jump-to-modal)
                id1.3.1.1.10(undo)
                id1.3.1.1.11(redo)
                id1.3.1.1.12("copy-to-clipboard (copy")
                id1.3.1.1.13("copy-to-clipboard (cut)")
                id1.3.1.1.14(paste-clipboard)
                id1.3.1.1.15(paste-clipboard)
            id1.3.1.2(:page-up)
            id1.3.1.3(:page-down)
            id1.3.1.4(:home)
            id1.3.1.5(:end)
            id1.3.1.6(:tab)
            id1.3.1.7(:leftarrow)
            id1.3.1.8(:rightarrow)
            id1.3.1.9(:uparrow)
            id1.3.1.10(:downarrow)
            id1.3.1.11(:ctrluparrow)
            id1.3.1.12(:ctrldownarrow)
            id1.3.1.13(:shiftleftarrow)
            id1.3.1.14(:shiftrightarrow)
            id1.3.1.15(:shiftuparrow)
            id1.3.1.16(:shiftdownarrow)
            id1.3.1.17(:shiftdel)
            id1.3.1.18(:enter)
            id1.3.1.19(:esc)
            id1.3.1.20(:backspace)
            id1.3.1.21(:del)
        id1.3.2(editor-handletyping)
    
    id1.4(exit)
        %% idt.3(disable-raw-mode)
        
%% Connections
%% idt.4 & idt.1 & idt.2 & idt.3 --> idt
id1 --> id1.1 & id1.2 & id1.3 & id1.4
    id1.1 --> idt.1 & id1.1.1 & id1.1.2
        id1.1.1 --> idt.4
    subgraph while
        id1.2 --> id1.2.1 & id1.2.2 & id1.2.3 & id1.2.4
            id1.2.3 --> id1.2.3.1 & id1.2.3.2 & id1.2.3.3 & id1.2.3.4 & id1.2.3.5 & id1.2.3.6 & id1.2.3.7 & id1.2.3.8 & id1.2.3.9 & id1.2.3.10 & id1.2.3.11 & id1.2.3.12
        id1.3 --> idt.2 & id1.3.1 & id1.3.2
            id1.3.1 --> id1.3.1.1 & id1.3.1.2 & id1.3.1.3 & id1.3.1.4 & id1.3.1.5 & id1.3.1.6 & id1.3.1.7 & id1.3.1.8 & id1.3.1.9 & id1.3.1.10 & id1.3.1.11 & id1.3.1.12 & id1.3.1.13 & id1.3.1.14 & id1.3.1.15 & id1.3.1.16 & id1.3.1.17 & id1.3.1.18 & id1.3.1.19 & id1.3.1.20 & id1.3.1.21 
                id1.3.1.1 --> id1.3.1.1.1 & id1.3.1.1.2 & id1.3.1.1.3 & id1.3.1.1.4 & id1.3.1.1.5 & id1.3.1.1.6 & id1.3.1.1.7 & id1.3.1.1.8 & id1.3.1.1.9 & id1.3.1.1.10 & id1.3.1.1.11 & id1.3.1.1.12 & id1.3.1.1.13 & id1.3.1.1.14 & id1.3.1.1.15
    end
    id1.4 --> idt.3

```