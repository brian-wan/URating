import React from 'react';
import './App.css';

class App extends React.Component{

  constructor(props) {
    super(props);
    this.state = {
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
        console.log(data)
      })
      .catch(err => {
        console.log(err)
      })
  }
  
  render(){
    return (
      <div className="App">

      </div>
    );
  }
}

export default App;
