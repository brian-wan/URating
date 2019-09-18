import React from 'react';
import "bootstrap/dist/css/bootstrap.min.css";
import { BrowserRouter as Router, Route, Link } from "react-router-dom";
import './App.css';
import Table from './Components/Table.js';
import CreateMatch from './Components/CreateMatch';

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
      <Router>
        <div className = "container-fluid">
          <div className = "row text-center">
            <h1 className = "col-12 mt-2">URating</h1>
          </div>
          <div className = "row bg-info mt-2 p-2">
            <nav className="navbar navbar-expand-lg navbar-light bg-light">
              <Link to="/" className="navbar-brand">URating App</Link>
              <div className="collapse navbar-collapse">
                <ul className="navbar-nav mr-auto">
                  <li className="navbar-item">
                    <Link to="/" className="nav-link">Matches</Link>
                  </li>
                  <li className="navbar-item">
                    <Link to="/create" className="nav-link">Create Match</Link>
                  </li>
                </ul>
              </div>
            </nav>
          </div>
          <div className = "row">
            <div className = "col-4 mx-auto mt-5"><Table matchList={this.state.matchList} matchTitle = {this.state.matchTitle}></Table></div>
          </div>
          <Route path="/" exact component={Table} />
          <Route path="/create" component={CreateMatch} />
        </div>
      </Router>
    );
  }
}

export default App;
