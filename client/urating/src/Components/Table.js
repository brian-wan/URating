import React, { Component } from 'react';
import Match from './Match.js';
import "bootstrap/dist/css/bootstrap.min.css";

export default class Table extends Component {

    render() {
        if (this.props.matchList === undefined || this.props.matchList[0] === undefined)
            return null;

        return (
            <div className = "list-group">
                {this.props.matchList.map((element) => 
                <div className = "card m-2 p-5">
                <Match 
                    matchID = {element.id} 
                    matchScore = {element.score} 
                    matchTitle = {element.title}>
                </Match>
                </div>)}
            </div>
        )
    }
}
