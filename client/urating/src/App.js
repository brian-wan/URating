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
        this.setState({
            matchList: data.matches,
            matchTitle: data.matches[0].title
        })
      })
      .catch(err => {
        console.log(err)
      })
  }
  
  render(){
    return (
      <div className = "container">
        <div className = "row text-center">
          <h1 className = "col-12 mt-5">URating</h1>
        </div>
        <div className = "row">
          <div className = "col-4 mx-auto mt-5"><Table matchList={this.state.matchList} matchTitle = {this.state.matchTitle}></Table></div>
        </div>
      </div>
    );
  }
}

export default App;
