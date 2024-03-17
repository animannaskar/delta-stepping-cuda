
#include <iostream>
#include <vector>
#include <queue>
#include <climits>
#include <fstream>
#include <sstream>
#include <chrono>

const int max_dist = 1e6;

using namespace std;

void read_adj_list(const string& filename, vector<int>& r, vector<int>& c) {
    ifstream file(filename);
    string line;

    int row_pointer = 0;
    while (getline(file, line)) {
        r.push_back(row_pointer);

        istringstream iss(line);
        int neighbor, weight;

        while (iss >> neighbor >> weight) {
            c.push_back(neighbor);
            c.push_back(weight);
            row_pointer+=2;
        }
    }
    r.push_back(row_pointer);
}

string get_arg(int argc, char *argv[], string arg_name){
    for(int i = 1; i < argc; i++){
        string arg_i = argv[i];
        if(arg_i == arg_name && i+1 < argc){
            string arg = argv[i+1];
            return arg;
        }
    }
    return "";
}

int main(int argc, char *argv[]){
    int src = 0;
    string graph_name = "100K";

    string arg;
    int temp;

    arg = get_arg(argc,argv,"-g");
    if(arg != "") graph_name = arg;

    ios_base::sync_with_stdio(false);
    cin.tie(NULL);
    cout.tie(NULL);

    string filename = "connected_graph_"+graph_name+".txt";
    string output_file_name = "output_SEQ_"+graph_name+".txt";


    ios_base::sync_with_stdio(false);
    cin.tie(NULL);
    cout.tie(NULL);


    vector<int> r, c;

    read_adj_list(filename, r, c);

    int n = r.size()-1;

    int distance[n];
    int processed[n] = {0};
    queue<pair<int,int>> q;

    for (int i = 0; i < n; i++) distance[i] = max_dist;
    distance[src] = 0;

    auto start_time = chrono::high_resolution_clock::now();

    int diameter = 0;

    q.push({0,src});
    while (!q.empty()) {
        int a = q.front().second; q.pop();
        for (int u = r[a]; u < r[a+1]; u+=2) {
            int b = c[u], w = c[u+1];
            if (distance[a]+w < distance[b]) {
                distance[b] = distance[a]+w;
                q.push({-distance[b],b});

                diameter = max(diameter, distance[b]);
            }
        }
    }

    cout << "diameter " << diameter << "\n";


    auto stop_time = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::microseconds>(stop_time - start_time);

    ofstream output_file(output_file_name);

    if (!output_file.is_open()) {
        cerr << "Error: Unable to open output file." << endl;
        return 1;
    }

    output_file << "Djikstra w/o copy time: " << duration.count()/1000.0 << " milliseconds" << endl;

    for (int i = 0; i < n; ++i) {
        output_file << "Distance to node " << i << ": " << distance[i] << endl;
    }

    output_file.close();

}
