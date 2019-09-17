import React from 'react';
import "bootstrap/dist/css/bootstrap.min.css";
import './App.css';
import Table from './Components/Table.js';

class App extends React.Component{

  constructor(props) {
    super(props);
    this.state = {
      matchList: [],
      matchTitle: ""
    }
  }

  componentDidMount = () => {
    console.log("Starting api call...");

    fetch('/urating/api/v1.0/matches', 
        {
          method: 'GET', 
        }
      )
      .then(res => res.json())
      .then(data => {
        //console.log(data)
        this.setState({
            matchList: data.matches,
            matchTitle: data.matches[0].title
        })
        //console.log(data.matches);
        //console.log(data.matches[0]);
        //console.log(data.matches[0].score);
      })
      .catch(err => {
        console.log(err)
      })
  }
  
  render(){
    return (
      <div className="App">
        <Table matchList={this.state.matchList} matchTitle = {this.state.matchTitle}></Table>
      </div>
    );
  }
}

export default App;
