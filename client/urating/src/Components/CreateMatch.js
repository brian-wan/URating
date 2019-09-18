import React, { Component } from 'react'
import "bootstrap/dist/css/bootstrap.min.css";

export default class CreateMatch extends Component {
    constructor(props) {
        super(props);

        this.state = {
            matchTitle: "",
            matchScore: "",
            matchCompleted: false
        }

        this.onChangeMatchTitle = this.onChangeMatchTitle.bind(this);
        this.onChangeMatchScore = this.onChangeMatchScore.bind(this);
        this.onSubmit = this.onSubmit.bind(this);
    }

    onChangeMatchTitle(e) {
        this.setState({
            matchTitle: e.target.value
        })
    }

    onChangeMatchScore(e) {
        this.setState({
            matchScore: e.target.value
        })
    }

    onSubmit(e) {
        e.preventDefault();
        
        /*console.log(`Form submitted:`);
        console.log(`Match Title: ${this.state.matchTitle}`);
        console.log(`Match Score: ${this.state.matchScore}`);*/

        this.setState({
            matchTitle: "",
            matchScore: "",
            matchCompleted: false
        })

        this.props.addMatch(this.state.matchTitle, this.state.matchScore);
    }

    render() {
        return (
            <div style={{marginTop: 10}}>
                <h3>Create New Match</h3>
                <form onSubmit={this.onSubmit}>
                    <div className="form-group"> 
                        <label>Match Title: </label>
                        <input  type="text"
                                className="form-control"
                                value={this.state.matchTitle}
                                onChange={this.onChangeMatchTitle}
                                />
                    </div>
                    <div className="form-group">
                        <label>Match Score: </label>
                        <input 
                                type="text" 
                                className="form-control"
                                value={this.state.matchScore}
                                onChange={this.onChangeMatchScore}
                                />
                    </div>

                    <div className="form-group">
                        <input type="submit" value="Create Match" className="btn btn-primary" />
                    </div>
                </form>
            </div>
        )
    }
}