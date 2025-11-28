import { useEffect, useRef } from "react"
import { Col, Form, InputGroup, Row } from "react-bootstrap";
import { getDate, getTime } from "../Util/FormatDateTime";

const RegPeriodForm=({regPeriodDTO,setRegPeriodDTO, semesters})=>{
          const openDateRef = useRef();
          const openTimeRef = useRef();
          const closeDateRef = useRef();
          const closeTimeRef = useRef();

          useEffect(()=>{
                    if(semesters.length!=0) regPeriodDTO.semester.id=semesters[0].id;
          },[])
          function handleOnChange(e, fieldName){
                    if(fieldName=="semester") setRegPeriodDTO(preDTO=>{
                              const updatedRegDTO={...preDTO}
                              updatedRegDTO.semester.id=e.target.value;
                              return updatedRegDTO;
                    })
                    else if(fieldName=="openTime") setRegPeriodDTO((preDTO)=>{
                              return {...preDTO, openTime:openDateRef.current.value+" "+openTimeRef.current.value}})
                    else if(fieldName=="closeTime")setRegPeriodDTO((preDTO)=>{
                              return {...preDTO, closeTime:closeDateRef.current.value+" "+closeTimeRef.current.value}})
          }
          return(
                    <Form>
                              <Row>
                                        <InputGroup className="mb-3">
                                                  <InputGroup.Text>OpenTime</InputGroup.Text>
                                                  <Form.Control type="date" ref={openDateRef} onChange={(e)=>handleOnChange(e,"openTime")} defaultValue={getDate(regPeriodDTO.openTime)}/>
                                                  <Form.Control type="time" step="1" ref={openTimeRef} onChange={(e)=>handleOnChange(e,"openTime")} defaultValue={getTime(regPeriodDTO.openTime)}/>
                                        </InputGroup>
                              </Row>
                              <Row>
                                        <InputGroup className="mb-3">
                                                  <InputGroup.Text>CloseTime</InputGroup.Text>
                                                  <Form.Control type="date" ref={closeDateRef} onChange={(e)=>handleOnChange(e,"closeTime")} defaultValue={getDate(regPeriodDTO.closeTime)}/>
                                                  <Form.Control type="time" step="1" ref={closeTimeRef} onChange={(e)=>handleOnChange(e,"closeTime")} defaultValue={getTime(regPeriodDTO.closeTime)}/>
                                        </InputGroup>
                              </Row>
                              <Row>
                                        <Form.Group as={Col} sm={7} controlId="semester">
                                                  <Form.Label>Học kì</Form.Label>
                                                  <Form.Select onChange={(e)=>handleOnChange(e,"semester")}>
                                                  {semesters.map((se)=>(<option value={se.id}>Kì {se.semesterNum}, năm {se.year}-{se.year+1}</option>))}
                                                  </Form.Select>
                                        </Form.Group>
                              </Row>
                    </Form>
          )
}
export default RegPeriodForm;