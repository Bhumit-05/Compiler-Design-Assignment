%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int value = 0;
int store_flag = 0;
char var;
int exec_next = 1;

int loop_count = 0;
int loop_index = -1;
char loop_buffer[10000];  // Store loop content

int instr_address = 0; // For object dump simulation

// Object dump simulation
void dump_instr(const char* instr, const char* operand) {
    printf("0x%04X:\t%-6s\t%s\n", instr_address, instr, operand ? operand : "");
    instr_address += 4;  // increment pseudo address
}
%}

%option caseless

%%

"LOAD"     { if (exec_next) { store_flag = 1; dump_instr("LOAD", ""); } }
"ADD"      { if (exec_next) { store_flag = 2; dump_instr("ADD", ""); } }
"SUB"      { if (exec_next) { store_flag = 3; dump_instr("SUB", ""); } }
"MUL"      { if (exec_next) { store_flag = 4; dump_instr("MUL", ""); } }
"DIV"      { if (exec_next) { store_flag = 5; dump_instr("DIV", ""); } }
"STORE"    { if (exec_next) { store_flag = 6; dump_instr("STORE", ""); } }
"IFZ"      {
              dump_instr("IFZ", "");
              if (value == 0) exec_next = 1;
              else exec_next = 0;
          }
"ENDIF"    { exec_next = 1; dump_instr("ENDIF", ""); }
"LOOP"     {
              if (exec_next) {
                  loop_index = 0;
                  loop_buffer[0] = '\0';
                  store_flag = 7;
                  dump_instr("LOOP", "");
              }
          }
"ENDLOOP"  {
              if (exec_next && loop_count > 0) {
                  dump_instr("ENDLOOP", "");
                  FILE *tmp = tmpfile();
                  fprintf(tmp, "%s", loop_buffer);
                  fseek(tmp, 0, SEEK_SET);
                  for (int i = 0; i < loop_count; i++) {
                      yyrestart(tmp);
                      yylex();
                  }
                  fclose(tmp);
                  loop_count = 0;
                  loop_index = -1;
              }
              store_flag = 0;
          }
"HLT"      {
              dump_instr("HLT", "");
              printf("Halting execution.\n");
              return 0;
          }

[0-9]+     {
              if (!exec_next) return 0;
              int num = atoi(yytext);
              char operand[20];
              sprintf(operand, "%d", num);
              dump_instr("VAL", operand);

              if (store_flag == 1) value = num;
              else if (store_flag == 2) value += num;
              else if (store_flag == 3) value -= num;
              else if (store_flag == 4) value *= num;
              else if (store_flag == 5) {
                  if (num != 0) value /= num;
                  else printf("Error: Division by zero!\n");
              } else if (store_flag == 7) loop_count = num;
              store_flag = 0;
           }

[A-Z]      {
              if (!exec_next) return 0;
              char operand[2] = { yytext[0], '\0' };
              dump_instr("REG", operand);

              if (store_flag == 6) {
                  var = yytext[0];
                  printf("Stored %d in variable %c\n", value, var);
                  store_flag = 0;
              } else {
                  printf("Token: %s (Register/Variable)\n", yytext);
              }
           }

[ \t\n]+   { /* skip whitespace */ }

.          {
              if (loop_index >= 0 && exec_next) {
                  strcat(loop_buffer, yytext);
                  strcat(loop_buffer, " ");
              } else if (exec_next) {
                  printf("Unknown token: %s\n", yytext);
              }
          }

%%

int main() {
    printf("Enter your instructions (END with HLT):\n");
    yylex();
    printf("Final Computed Value: %d\n", value);
    return 0;
}

int yywrap() {
    return 1;
}
