import React from "react";
const TableHeader = ({data}) => {
    return (
        <thead className="table-dark header">
            <tr>
                {data.map((header, index) => {
                    if(header==="Action") return (<th scope="col" colSpan={2} key={index}>{header}</th>)
                    else return (<th scope="col" key={index}>{header}</th>)
                })}
            </tr>
        </thead>
    );
}

export default TableHeader;