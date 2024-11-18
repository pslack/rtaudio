//
// Created by Peter Slack on 2023-10-29.
//

#include <iostream>
#include <string>
#include <vector>
#include <sstream>
//write a function to execute process otool utility and get the output into a string array
// input is a string to the base path
// output is a vector of strings of the dependencies in the base library

#include <cstdio>
#include <memory>
#include <stdexcept>
#include <array>
#include <filesystem>
#include <dlfcn.h>

#include <unistd.h>

struct CommandResult {
    std::string output;
    int exitstatus;
    friend std::ostream &operator<<(std::ostream &os, const CommandResult &result) {
        os << "command exitstatus: " << result.exitstatus << " output: " << result.output;
        return os;
    }
    bool operator==(const CommandResult &rhs) const {
        return output == rhs.output &&
               exitstatus == rhs.exitstatus;
    }
    bool operator!=(const CommandResult &rhs) const {
        return !(rhs == *this);
    }
};

class Command {
public:
    /**
         * Execute system command and get STDOUT result.
         * Regular system() only gives back exit status, this gives back output as well.
         * @param command system command to execute
         * @return commandResult containing STDOUT (not stderr) output & exitstatus
         * of command. Empty if command failed (or has no output). If you want stderr,
         * use shell redirection (2&>1).
         */
    static CommandResult exec(const std::string &command) {
        int exitcode = 0;
        std::array<char, 1048576> buffer  {};

        std::string result;
#ifdef _WIN32
        #define popen _popen
#define pclose _pclose
#define WEXITSTATUS
#endif
        FILE *pipe = popen(command.c_str(), "r");
        if (pipe == nullptr) {
            throw std::runtime_error("popen() failed!");
        }
        try {
            std::size_t bytesread;
            while ((bytesread = std::fread(buffer.data(), sizeof(buffer.at(0)), sizeof(buffer), pipe)) != 0) {
                result += std::string(buffer.data(), bytesread);
            }
        } catch (...) {
            pclose(pipe);
            throw;
        }
        exitcode = pclose(pipe);
        return CommandResult{result, exitcode};
    }

};




/// \brief check if a string ends with a given string
/// \param fullString
/// \param ending
/// \return
bool hasEnding (std::string const &fullString, std::string const &ending) {
    if (fullString.length() >= ending.length()) {
        return (0 == fullString.compare (fullString.length() - ending.length(), ending.length(), ending));
    } else {
        return false;
    }
}

// trim from left
inline std::string& ltrim(std::string& s, const char* t = " \t\n\r\f\v")
{
    s.erase(0, s.find_first_not_of(t));
    return s;
}

// trim from right
inline std::string& rtrim(std::string& s, const char* t = " \t\n\r\f\v")
{
    s.erase(s.find_last_not_of(t) + 1);
    return s;
}

// trim from left & right
inline std::string& trim(std::string& s, const char* t = " \t\n\r\f\v")
{
    return ltrim(rtrim(s, t), t);
}

// copying versions

inline std::string ltrim_copy(std::string s, const char* t = " \t\n\r\f\v")
{
    return ltrim(s, t);
}

inline std::string rtrim_copy(std::string s, const char* t = " \t\n\r\f\v")
{
    return rtrim(s, t);
}

inline std::string trim_copy(std::string s, const char* t = " \t\n\r\f\v")
{
    return trim(s, t);
}
// function to determine if string begins with another string
// inputs string to search
// string to search for
// returns true if string begins with search string
bool begins_with(std::string const &full_string, std::string const &search_string) {
    if (full_string.length() >= search_string.length()) {
        return (0 == full_string.compare(0, search_string.length(), search_string));
    } else {
        return false;
    }
}

/// \brief execute a shell command and return the output as a string
/// \param cmd
/// \return
std::string exec(const char* cmd) {
//    std::array<char, 512> buffer;
//    std::string result;
//    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
//    if (!pipe) {
//        throw std::runtime_error("popen() failed!");
//    }
//    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
//        result += buffer.data();
//    }

    CommandResult commandResult = Command::exec(cmd);

    return commandResult.output;




}

/// \brief get the executable name from the Info.plist file
/// \param base_path full path to .framework directory
/// \return
std::string get_framework_executable_name(std::string base_path){

    std::stringstream cmd;
    std::string executable_name;
    cmd << "/usr/libexec/PlistBuddy -c \"Print CFBundleExecutable\" " << "\"" << base_path << "\"" << "/Resources/Info.plist";

    try {

        std::string output = exec(cmd.str().c_str());

        // remove the newline from the output
//        output.erase(std::remove(output.begin(), output.end(), '\n'), output.end());
        rtrim(output);
        ltrim(output);

        executable_name = output;

    } catch (std::exception& e) {
        std::cout << "exception caught: " << e.what() << std::endl;
    }

    return executable_name;
}

/// function to get the filename of a dylib given the full path to dylib
/// \param full_path
/// \return
std::string get_dylib_filename(std::string full_path) {

    // if string begins with @rpath then replace @rpath
    // with the current working directory
    if(begins_with(full_path, "@rpath")) {
        full_path = std::filesystem::current_path().string() + full_path.substr(6);
    }
    // check file exists and it is a regular file
    std::FILE *directory = std::fopen(full_path.c_str(), "r");
    if (directory == NULL)
    {
        std::cout << "Directory does not exist" << std::endl;
        return std::string();

    }
    std::fclose(directory);

    std::filesystem::path p(full_path);

    // get the filename from the full path
    // remove the path from the filename
    // remove the .dylib extension from the filename

    // get the filename from the full path
    std::string filename = p.filename().string();

    return filename;
}

/// \brief get the dependencies of an executable or library using otool
/// \param base_path full path to the library or executable
/// \return a vector of paths to dependencies using otool listing
static std::vector<std::string> get_dependencies(std::string base_path) {

    // execute shell command otool -L base_path
    // parse the output and return a vector of strings
    // 1. execute shell command
    // 2. parse the output
    // 3. return a vector of strings

    std::stringstream cmd;
    std::vector<std::string> dependencies;
    cmd << "otool -L " << "\"" << base_path << "\"" << " | grep -oE '(\\/.+?|@loader_path\\/.+?|@rpath\\/.+?) '";

    try {

        std::string output = exec(cmd.str().c_str());
        //std::cout << "*** output: " << output << "****" << std::endl;


        std::istringstream iss(output);
        std::string temp;
        // Get the input from the input file until EOF
        while (std::getline(iss, temp, '\n')) {
            // Add to the list of output strings
            // remove newline and spaces from from the string
            rtrim(temp);
            ltrim(temp);

            dependencies.push_back(temp);
        }

    } catch (std::exception& e) {
        std::cout << "exception caught: " << e.what() << std::endl;
    }

    // get the system file name of path handed in
    std::string filename = get_dylib_filename(base_path);

    // remove any entry that begins with /System or /usr/lib
    dependencies.erase(std::remove_if(dependencies.begin(), dependencies.end(), [](const std::string& s) {
        return s.find("/System") == 0 || s.find("/usr/lib") == 0;
    }), dependencies.end());

    // remove the entries that have the filename of the base_path
    dependencies.erase(std::remove_if(dependencies.begin(), dependencies.end(), [filename](const std::string& s) {
        return s.find(filename) != std::string::npos;
    }), dependencies.end());


    return dependencies;
}


class target_library {
public:
    target_library(std::string full_path) :m_dependencies() {

        file_path = full_path;
        // if full path begins with @rpath/ then replace @rpath with the current working directory
        if(begins_with(full_path, "@rpath")) {
            isSwapped = true;
            file_path = std::filesystem::current_path().string() + full_path.substr(6);
            rpath_original = full_path;
        }
        m_name = get_dylib_filename(full_path);
    }
    ~target_library() {
        //std::cout << "target_library destructor" << std::endl;
    }

    // compare operator
    bool operator==(const target_library& rhs) const {
        return m_name == rhs.m_name;
    }

    void gather_dependencies() {
        // get the dependencies of the executable
        std::vector<std::string> dependencies = ::get_dependencies(file_path);
        // dependencies cannot be empty
        if(dependencies.empty()) {
            std::cout << "dependencies is empty" << std::endl;
        }

        for (int i=0 ; i< dependencies.size(); i++ ) {
            auto dps = dependencies[i];
            // ignore any rpaths in the mix
//            if(begins_with(dps, "@rpath") ) {
//                // replace @rpath with the current working directory
//                dps = std::filesystem::current_path().string() + dps.substr(6);
//            }
//            // check if this is a symlink, if it is then replace it with the real full path
//            std::filesystem::path p(dps);
//
//            if(std::filesystem::is_symlink(p)) {
//                std::filesystem::path real_path = std::filesystem::read_symlink(p);
//                // if there is no parent folder in path then add the current working directory
//                if(real_path.parent_path().empty()) {
//                    dps = std::filesystem::current_path().string() + "/" + real_path.string();
//                } else {
//                    dps = real_path.string();
//                }
//
//
//            }


            add_dependency(dps);
        }
    }
    void set_name(std::string name) {
        m_name = name;
    }
    std::string get_name() {
        return m_name;
    }
    void set_file_path(std::string path) {
        file_path = path;
    }
    std::string get_file_path() {
        return file_path;
    }
    const std::vector<std::string> & get_dependencies() {
        return m_dependencies;
    }
    void print() {
        std::cout << "name: " << m_name << std::endl;
        std::cout << "file_path: " << file_path << std::endl;
        std::cout << "dependencies: " << std::endl;
        for(auto& dependency : m_dependencies) {
            std::cout << "   " << dependency << std::endl;
        }
    }

private:
    std::string m_name;
    std::string file_path;
    std::string rpath_original;
    bool isSwapped = false;

    // test a framework lib
    std::vector<std::string> m_dependencies;
    void add_dependency(std::string dependency) {
        m_dependencies.push_back(dependency);
    }


};

static std::vector<target_library> master_list;
static bool dryrun = false;

/// recursive library processor to build the master list
/// \param base_path


void process_library(std::string base_path){

        // get the executable name for input framework
        std::string executable_name = get_dylib_filename(base_path);
        //executable name cannot be empty
        if(executable_name.empty()) {
            std::cout << "executable_name is empty" << std::endl;
            return;
        }
    // create a target_library object
    target_library target(base_path);
    target.gather_dependencies();

    //if the target_library object is already in the master_list
        // do nothing
        auto it = std::find(master_list.begin(), master_list.end(), target);
        if(it != master_list.end()) {
            // target_library object is already in the master_list
            // do nothing
            return;
        }

    // add the target_library object to the master_list
    master_list.push_back(target);


        // iterate through the dependencies
        for(auto& dependency : target.get_dependencies()) {

            // check if the dependency is already in the master_list
            if (hasEnding(dependency, executable_name)) {
                // dependency is not a dylib
                // do nothing
                continue;
            }

            auto it = std::find(master_list.begin(), master_list.end(), dependency);
            if(it != master_list.end()  || hasEnding(dependency, executable_name)) {
                // dependency is already in the master_list
                // do nothing
            } else {

                process_library(dependency);
            }
        }


}


void relocate_libraries(target_library lib_to_process, std::filesystem::path destination_file) {



    //for each dependency in the target_library object
    //run the install_name_tool to change the path of the dependency to @rpath/dependency
    std::string base_relocation_path = "@loader_path/";

//    if (lib_to_process.get_name() == base_framework_executable_name) {
//        base_relocation_path += base_framework_name + "/Libraries/";
//    }


    for(auto dependency : lib_to_process.get_dependencies()) {


            std::stringstream cmd;
            std::string dylibname = get_dylib_filename(dependency);

            std::string relocate_destination = base_relocation_path + dylibname;
            if(hasEnding(dependency, lib_to_process.get_name())) {
                cmd  << "install_name_tool -id "  <<  "@loader_path/"  << dylibname << " " << destination_file;

            } else {
                cmd  << "install_name_tool -change "  << dependency << " " << relocate_destination << " " << destination_file;
            }

            std::cout << cmd.str() << std::endl;
            if (!dryrun)
                exec(cmd.str().c_str());

    }
}


void copy_all_libraries(std::filesystem::path destination_path) {

    std::cout << "master_list size: " << master_list.size() << std::endl;
    for(auto target : master_list) {
        std::filesystem::path source_path = target.get_file_path();
        std::filesystem::path destination_file = destination_path / source_path.filename();


        std::cout << "evaluating " << target.get_name() << std::endl;


             std::cout << "copying: " << source_path << " to " << destination_file << std::endl;
             if(!dryrun) {
                 std::filesystem::copy_file(source_path, destination_file,
                                            std::filesystem::copy_options::overwrite_existing);

                 // if the source file is a symlink then copy the base reference file as well
                    std::filesystem::path p(source_path);
                    if(std::filesystem::is_symlink(p)) {
                        std::filesystem::path real_path = std::filesystem::read_symlink(p);
                        std::filesystem::path destination_file = destination_path / real_path.filename();
                        std::cout << "copying: " << real_path << " to " << destination_file << std::endl;
                        std::filesystem::copy_file(real_path, destination_file,
                                                   std::filesystem::copy_options::overwrite_existing);
                    }

                 // change the file to read write
                 std::filesystem::permissions(destination_file, std::filesystem::perms::owner_write,
                                              std::filesystem::perm_options::add);

        }
    }


    for(auto target : master_list) {
        std::filesystem::path source_path = target.get_file_path();
        std::filesystem::path destination_file = destination_path / source_path.filename();


        std::cout << "relocating " << target.get_name() << std::endl;

        relocate_libraries(target, destination_file);


    }



}


/// function to look for command switches in the command line input
/// \param argc
/// \param argv
/// \param sw
/// \return
bool find_switch(int argc, const char * argv[], std::string sw) {
    for(int i = 0; i < argc; i++) {
        if(argv[i] == sw) {
            return true;
        }
    }
    return false;
}

// function to dunp listing of open files attached to this process
void dump_open_files() {
    std::cout << "dump_open_files" << std::endl;
    std::string cmd = "lsof -p " + std::to_string(getpid()) + "| awk '{print $9}'";
    std::cout << cmd << std::endl;
    system(cmd.c_str());
}


/// function to dlopen and close a framework to test pathing
/// \param path
void test_framework(std::string path) {
    void *handle;
    handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL );
    if (!handle) {
        std::cerr << "Cannot open library: " << dlerror() << '\n';
        return;
    }

   dump_open_files();


    // use it
    dlclose(handle);
}

/// c++17  function to add an environment varialble
/// \param name
/// \param value
void set_env_var(std::string name, std::string value) {
    std::string env_var = name + "=" + value;
    if ( !setenv((char*)env_var.c_str(), (char*)value.c_str(), 1) ) {
        std::cout << "setenv() failed" << std::endl;
    }
}


int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";

    if(argc < 2) {
        std::cout << "base_path is empty" << std::endl;
        return 0;
    }

    std::string base_path = argv[1];

    std::cout << "base_path: " << base_path << std::endl;



    // set DYLIB_PRINT_LIBRARIES to 1 to print the libraries
    set_env_var("DYLD_PRINT_LIBRARIES", "1");

    if (const char* env_p = std::getenv("DYLD_PRINT_LIBRARIES"))
        std::cout << "Your PATH is: " << env_p << '\n';

    if (const char* env_p = std::getenv("LD_RUNPATH_SEARCH_PATHS"))
        std::cout << "Your R-PATH is: " << env_p << '\n';


    if(base_path.empty()) {
        std::cout << "base_path is empty" << std::endl;
        return 1;
    }


    process_library(base_path);



    for (auto& p: master_list) {
        std::cout << p.get_file_path() << std::endl;
    }

    //get the parent folder name of the base_path
    std::filesystem::path base_path_path = base_path;


std::string lib_dir_path_str =base_path_path.parent_path().string() + "/Libraries";

std::filesystem::path lib_dir_path(lib_dir_path_str);

std::filesystem::create_directory(lib_dir_path);

std::string top_lib = base_path_path.filename().string();

std::filesystem::path test_path (lib_dir_path_str + "/" + top_lib);

    copy_all_libraries(lib_dir_path);



    // test open and close the framework
    test_framework(test_path.string());









    return 0;
}

