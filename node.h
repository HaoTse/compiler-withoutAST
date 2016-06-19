#include "header.h"

typedef struct _attribute
{
    string type;
    int offset; // means different in local and param
    int scope; // 0 is global, 1 is param, 2 is local
    int array_size; // in global and local means size of array, in param means if it is an array
}Attribute;

class SymbolTable{
public:

    int branch_cnt;
    int loop_cnt;
    
    SymbolTable(){
        total_offset = 0;
        branch_cnt = loop_cnt = 0;

        map<string, Attribute> global, param;
        _scope.push_back(global);
        _scope.push_back(param);
    }

    void InitFuncParam(){
        func_param_cnt = 0;
    }


    void Add(const string &type, const string &identifier, int scope, int size = 1){
        Attribute tmp;
        tmp.type = type;
        if(scope == 0){
            tmp.scope = 0;
            tmp.offset = 0;
            tmp.array_size = size;
            _scope[0][identifier] = tmp;
        }
        else if(scope == 1){
            tmp.scope = 1;
            tmp.offset = func_param_cnt++;
            tmp.array_size = size;
            _scope[1][identifier] = tmp;
        }
        else{
            tmp.scope = 2;
            tmp.array_size = size;
            total_offset -= size * 4;
            tmp.offset = total_offset;
            _scope[_scope.size() - 1][identifier] = tmp;
        }

        if(break_offset.size())
            break_offset[break_offset.size() - 1] -= size * 4;

    }

    Attribute Lookup(const string &identifier){
        int size = _scope.size();
        for(int i = size - 1; i >= 0; i--){
            map<string, Attribute>::iterator it = _scope[i].find(identifier);
            if(it != _scope[i].end())
                return _scope[i][identifier];
        }
    }

    void EnterScope(){
        map<string, Attribute> tmp;
        _scope.push_back(tmp);
    }

    string LeaveScope(){
        map<string, Attribute> cur_scope;
        int cur_offset = 0;

        cur_scope = _scope[_scope.size() - 1];
        for(map<string, Attribute>::iterator it = cur_scope.begin(); it != cur_scope.end(); it++){
            int size = (it -> second).array_size;
            cur_offset -= size * 4;
        }

        total_offset -= cur_offset;

        _scope.erase(_scope.end() - 1);

        return to_string(-cur_offset);
    }

    void EnterWhile(){
        break_offset.push_back(0);
    }

    void LeaveWhile(){
        break_offset.erase(break_offset.end() - 1);
    }

    string GetBreakOffset(){
        int tmp = break_offset[break_offset.size() - 1];
        return to_string(-tmp);
    }

    string GetOffset(){
        return to_string(-total_offset);
    }

private:
    vector<map<string, Attribute> > _scope;
    vector<int> break_offset;
    map<string, int> global_var;
    map<string, int> _param;
    int total_offset;
    int func_param_cnt;
};

class Register{
public:

    Register(){
        memset(reg_used, false, sizeof(reg_used));
    }

    string GetFreeRegister(){
        for (int i = 0; i < 10; ++i){
            if(!reg_used[i]){
                reg_used[i] = true;
                return "$t" + to_string(i);
            }
        }
        return "no free temporaries";
    }

    void FreeRegister(string &_reg){
        int tmp = _reg[2] - '0';
        reg_used[tmp] = false;
    }
    
private:
    bool reg_used[8];
};